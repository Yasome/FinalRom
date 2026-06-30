import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'package:chdman_ffi/chdman_ffi.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../services/chd_worker.dart';
import 'queue_progress.dart';
import 'package:logging/logging.dart';

// --- Job ---
/// One CHD operation in a queue: a single create or extract with its own input
/// and output paths. A queue of one is the former single-file behavior.
class ChdJob extends Equatable {
  final ChdAction action;
  final String inputPath;

  /// For [ChdAction.create] this is the `.chd` output; for [ChdAction.extract]
  /// it is the `.cue` output.
  final String outputPath;

  /// The `.bin` output, used only for a CD [ChdAction.extract].
  final String? outputBinPath;

  /// For [ChdAction.extract], true when the input CHD is a DVD CHD (detected up
  /// front via [chdmanChdIsDvd]); it is then extracted to the single `.iso` at
  /// [outputPath]. Always false for create.
  final bool sourceIsDvd;

  const ChdJob({
    required this.action,
    required this.inputPath,
    required this.outputPath,
    this.outputBinPath,
    this.sourceIsDvd = false,
  });

  @override
  List<Object?> get props =>
      [action, inputPath, outputPath, outputBinPath, sourceIsDvd];
}

// --- Events ---
abstract class ChdEvent extends Equatable {
  const ChdEvent();
  @override
  List<Object?> get props => [];
}

class StartChd extends ChdEvent {
  /// The files to process, one after another.
  final List<ChdJob> jobs;
  final bool force;

  /// Tunable chdman options. [force] (above) takes precedence over
  /// [options.force] so existing callers keep working.
  final ChdOptions options;

  /// When true, create jobs produce DVD CHDs (chdman createdvd) instead of CD
  /// CHDs. Applies to the whole queue; ignored by extract jobs.
  final bool createDvd;

  const StartChd({
    required this.jobs,
    this.force = false,
    this.options = const ChdOptions(),
    this.createDvd = false,
  });

  @override
  List<Object?> get props => [jobs, force, options, createDvd];
}

class CancelChd extends ChdEvent {}

class _ChdFinished extends ChdEvent {
  final ChdResult result;
  const _ChdFinished(this.result);
}

class _ChdProgressUpdate extends ChdEvent {
  final double fraction; // 0.0 .. 1.0
  const _ChdProgressUpdate(this.fraction);

  @override
  List<Object?> get props => [fraction];
}

// --- States ---
abstract class ChdState extends Equatable {
  const ChdState();
  @override
  List<Object?> get props => [];
}

class ChdIdle extends ChdState {}

class ChdRunning extends ChdState {}

/// Emitted while an operation runs, carrying its 0.0..1.0 completion fraction
/// and which file in the queue it belongs to.
class ChdProgress extends ChdState {
  final double fraction;
  final QueuePosition position;
  const ChdProgress(this.fraction, this.position);

  @override
  List<Object?> get props => [fraction, position];
}

/// Emitted once the whole queue has finished (or been cancelled). [results]
/// holds one entry per file that ran.
class ChdBatchDone extends ChdState {
  final List<JobResult> results;
  final Duration duration;
  const ChdBatchDone(this.results, {this.duration = Duration.zero});

  @override
  List<Object?> get props => [results, duration];
}

// --- Bloc ---
class ChdBloc extends Bloc<ChdEvent, ChdState> {
  final _logger = Logger('ChdBloc');
  ReceivePort? _receivePort;
  DateTime? _startTime;

  // The queue being processed and our position within it.
  List<ChdJob> _jobs = const [];
  int _currentIndex = 0;
  final List<JobResult> _results = [];

  // Shared options/force for every job in the current queue.
  ChdOptions _options = const ChdOptions();

  // Whether create jobs in the current queue produce DVD CHDs instead of CD.
  bool _createDvd = false;

  // Shared native cell the worker isolate writes progress (0..1000) into while
  // it is blocked in the synchronous FFI call. This (main) isolate polls it.
  Pointer<Int32>? _progressCell;
  Timer? _progressTimer;

  // Shared native cell we set to 1 to request cancellation. The native code is
  // synchronous, so Isolate.kill() cannot interrupt it (and would orphan the
  // native work + risk a use-after-free on the cells it is still writing).
  // Instead we cooperatively signal here and wait for the worker to return.
  Pointer<Int32>? _cancelCell;

  // True between spawning the worker and receiving its result. While true, the
  // native call may still be writing to the shared cells, so they must not be
  // freed.
  bool _workerActive = false;

  // True once cancellation has been requested for the in-flight operation, so
  // the eventual _ChdFinished is treated as a cancel rather than success/error.
  bool _cancelRequested = false;

  // True once the user cancelled the queue, so no further jobs are started.
  bool _queueCancelled = false;

  ChdBloc() : super(ChdIdle()) {
    on<StartChd>(_onStartChd);
    on<CancelChd>(_onCancelChd);
    on<_ChdFinished>(_onChdFinished);
    on<_ChdProgressUpdate>(_onChdProgressUpdate);
  }

  Future<void> _onStartChd(StartChd event, Emitter<ChdState> emit) async {
    if (event.jobs.isEmpty) return;
    final queueDiscNote = event.jobs.first.action == ChdAction.create
        ? ' as ${event.createDvd ? 'DVD' : 'CD'}'
        : '';
    _logger.info(
        'Starting CHD queue: ${event.jobs.length} job(s)$queueDiscNote.');
    // A previous operation must have finished before a new one starts; the UI
    // gates this. Defensively, if one is somehow still in flight, signal it to
    // cancel and drop our references — the worker frees nothing, so the cells
    // it still owns are intentionally leaked rather than freed under it.
    if (_workerActive) {
      _cancelCell?.value = 1;
      _detachResources();
    }
    _disposeIdleResources();

    _jobs = event.jobs;
    _currentIndex = 0;
    _results.clear();
    _queueCancelled = false;
    // force takes precedence so the simple force flag keeps working.
    _options = ChdOptions(
      codecs: event.options.codecs,
      numProcessors: event.options.numProcessors,
      hunkBytes: event.options.hunkBytes,
      force: event.force || event.options.force,
    );
    _createDvd = event.createDvd;
    _startTime = DateTime.now();

    _startJob(_jobs[_currentIndex], emit);
  }

  /// Spawns the worker for a single job and starts polling its progress. Mirrors
  /// the original single-file start path; called once per file in the queue.
  void _startJob(ChdJob job, Emitter<ChdState> emit) {
    final actionLabel = job.action == ChdAction.create
        ? 'create (${_createDvd ? 'DVD' : 'CD'})'
        : 'extract (${job.sourceIsDvd ? 'DVD' : 'CD'})';
    _logger.info('CHD job ${_currentIndex + 1}/${_jobs.length}: '
        'action=$actionLabel, path=${job.inputPath}');
    _cancelRequested = false;
    emit(ChdProgress(0, _position));

    _progressCell = calloc<Int32>();
    _progressCell!.value = 0;
    _cancelCell = calloc<Int32>();
    _cancelCell!.value = 0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      final cell = _progressCell;
      if (cell == null) return;
      add(_ChdProgressUpdate(cell.value.clamp(0, 1000) / 1000.0));
    });

    _receivePort = ReceivePort();
    _receivePort!.listen((message) {
      if (message is ChdResult) {
        add(_ChdFinished(message));
      }
    });

    try {
      Isolate.spawn(
        ChdWorker.runChd,
        ChdParams(
          action: job.action,
          inputPath: job.inputPath,
          outputPath: job.outputPath,
          outputBinPath: job.outputBinPath,
          options: _options,
          createDvd: _createDvd,
          sourceIsDvd: job.sourceIsDvd,
          progressAddress: _progressCell!.address,
          cancelAddress: _cancelCell!.address,
          sendPort: _receivePort!.sendPort,
        ),
      );
      _workerActive = true;
    } catch (e) {
      add(_ChdFinished(ChdResult(success: false, error: e.toString())));
    }
  }

  QueuePosition get _position =>
      QueuePosition(currentIndex: _currentIndex + 1, total: _jobs.length);

  void _onChdProgressUpdate(_ChdProgressUpdate event, Emitter<ChdState> emit) {
    // Only report progress while an operation is in flight.
    if (state is ChdProgress || state is ChdRunning) {
      emit(ChdProgress(event.fraction, _position));
    }
  }

  void _onCancelChd(CancelChd event, Emitter<ChdState> emit) {
    _queueCancelled = true;
    if (!_workerActive) {
      // Nothing native is running; safe to free immediately.
      _disposeIdleResources();
      emit(_doneState());
      return;
    }

    // Cooperatively ask the native code to stop. We must NOT free the shared
    // cells or kill the isolate here: the synchronous FFI call is still
    // writing to them and only the native side can stop it. The worker will
    // send a cancelled _ChdFinished once it returns, and _onChdFinished then
    // frees everything and ends the queue. Stop polling progress now.
    _logger.info('Cancellation requested; signalling native chdman to stop.');
    _cancelRequested = true;
    _cancelCell?.value = 1;
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _onChdFinished(_ChdFinished event, Emitter<ChdState> emit) {
    final wasCancelled = _cancelRequested || event.result.cancelled;
    _cancelRequested = false;
    final job = _jobs[_currentIndex];
    _disposeIdleResources();

    if (wasCancelled) {
      _logger.info('CHD job cancelled; partial output removed.');
      // Cancelling stops the whole queue. Surface what completed before it.
      emit(_doneState());
      return;
    }

    if (event.result.success) {
      _results.add(JobResult(
        inputPath: job.inputPath,
        outputPath: event.result.path ?? job.outputPath,
        success: true,
      ));
    } else {
      _logger.severe('CHD job failed: ${event.result.error}');
      _results.add(JobResult(
        inputPath: job.inputPath,
        success: false,
        error: event.result.error ?? 'Unknown error',
      ));
    }

    _currentIndex++;
    if (!_queueCancelled && _currentIndex < _jobs.length) {
      _startJob(_jobs[_currentIndex], emit);
    } else {
      emit(_doneState());
    }
  }

  ChdBatchDone _doneState() {
    final duration =
        _startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero;
    _logger.info('CHD queue finished: ${_results.successCount}/${_jobs.length} '
        'succeeded in ${duration.inMilliseconds}ms.');
    return ChdBatchDone(List.unmodifiable(_results), duration: duration);
  }

  /// Frees the shared cells and tears down the isolate/port. Only safe to call
  /// when no native call is in flight (i.e. after the worker has returned, or
  /// before one starts) — otherwise native code would write to freed memory.
  void _disposeIdleResources() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _receivePort?.close();
    _receivePort = null;
    // The worker isolate exits on its own once runChd returns; we never kill it
    // mid-call (that cannot interrupt the synchronous native work anyway).
    _workerActive = false;
    if (_progressCell != null) {
      calloc.free(_progressCell!);
      _progressCell = null;
    }
    if (_cancelCell != null) {
      calloc.free(_cancelCell!);
      _cancelCell = null;
    }
  }

  /// Drops references to the shared cells WITHOUT freeing them, for the case
  /// where a native call is still running and we cannot start a new one over
  /// it. The orphaned cells (a few bytes) leak deliberately rather than risk a
  /// use-after-free; the abandoned operation finishes in the background.
  void _detachResources() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _receivePort?.close();
    _receivePort = null;
    _progressCell = null;
    _cancelCell = null;
    _workerActive = false;
  }

  @override
  Future<void> close() {
    if (_workerActive) {
      // A native call is still running; signal it and detach (the cells outlive
      // us via the running native code, so we can't free them safely here).
      _cancelCell?.value = 1;
      _detachResources();
    } else {
      _disposeIdleResources();
    }
    return super.close();
  }
}
