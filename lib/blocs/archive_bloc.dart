import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:equatable/equatable.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';

import '../services/archive_service.dart';
import '../services/archive_worker.dart';
import 'queue_progress.dart';

/// One archive operation in a queue: a single compress or decompress with its
/// own input and output paths. A queue of one is the single-file case.
class ArchiveJob extends Equatable {
  final ArchiveAction action;
  final String inputPath;

  /// The produced archive (compress) or the restored file / extraction
  /// directory (decompress).
  final String outputPath;

  final ArchiveFormat format;

  const ArchiveJob({
    required this.action,
    required this.inputPath,
    required this.outputPath,
    required this.format,
  });

  @override
  List<Object?> get props => [action, inputPath, outputPath, format];
}

// --- Events ---
abstract class ArchiveEvent extends Equatable {
  const ArchiveEvent();
  @override
  List<Object?> get props => [];
}

class StartArchive extends ArchiveEvent {
  final List<ArchiveJob> jobs;

  /// Compression level, or null for each format's default.
  final int? level;

  const StartArchive({required this.jobs, this.level});

  @override
  List<Object?> get props => [jobs, level];
}

class CancelArchive extends ArchiveEvent {}

class _ArchiveFinished extends ArchiveEvent {
  final ArchiveResult result;
  const _ArchiveFinished(this.result);
}

class _ArchiveProgressUpdate extends ArchiveEvent {
  final double fraction; // 0.0 .. 1.0
  const _ArchiveProgressUpdate(this.fraction);

  @override
  List<Object?> get props => [fraction];
}

// --- States ---
abstract class ArchiveState extends Equatable {
  const ArchiveState();
  @override
  List<Object?> get props => [];
}

class ArchiveIdle extends ArchiveState {}

class ArchiveRunning extends ArchiveState {}

/// Emitted while an operation runs, carrying its 0.0..1.0 completion fraction
/// and which file in the queue it belongs to.
class ArchiveProgress extends ArchiveState {
  final double fraction;
  final QueuePosition position;
  const ArchiveProgress(this.fraction, this.position);

  @override
  List<Object?> get props => [fraction, position];
}

/// Emitted once the whole queue has finished (or been cancelled).
class ArchiveBatchDone extends ArchiveState {
  final List<JobResult> results;
  final Duration duration;
  const ArchiveBatchDone(this.results, {this.duration = Duration.zero});

  @override
  List<Object?> get props => [results, duration];
}

/// Sequential queue runner for general compress/decompress jobs. Mirrors
/// [ChdBloc]: each job runs in a worker isolate, progress is polled from a
/// shared native cell, and cancellation is cooperative via a second cell.
class ArchiveBloc extends Bloc<ArchiveEvent, ArchiveState> {
  final _logger = Logger('ArchiveBloc');
  ReceivePort? _receivePort;
  DateTime? _startTime;

  List<ArchiveJob> _jobs = const [];
  int _currentIndex = 0;
  final List<JobResult> _results = [];
  int? _level;

  Pointer<Int32>? _progressCell;
  Timer? _progressTimer;
  Pointer<Int32>? _cancelCell;

  bool _workerActive = false;
  bool _cancelRequested = false;
  bool _queueCancelled = false;

  ArchiveBloc() : super(ArchiveIdle()) {
    on<StartArchive>(_onStartArchive);
    on<CancelArchive>(_onCancelArchive);
    on<_ArchiveFinished>(_onArchiveFinished);
    on<_ArchiveProgressUpdate>(_onArchiveProgressUpdate);
  }

  Future<void> _onStartArchive(
      StartArchive event, Emitter<ArchiveState> emit) async {
    if (event.jobs.isEmpty) return;
    _logger.info('Starting archive queue: ${event.jobs.length} job(s).');
    if (_workerActive) {
      _cancelCell?.value = 1;
      _detachResources();
    }
    _disposeIdleResources();

    _jobs = event.jobs;
    _currentIndex = 0;
    _results.clear();
    _queueCancelled = false;
    _level = event.level;
    _startTime = DateTime.now();

    _startJob(_jobs[_currentIndex], emit);
  }

  void _startJob(ArchiveJob job, Emitter<ArchiveState> emit) {
    _logger.info('Archive job ${_currentIndex + 1}/${_jobs.length}: '
        'action=${job.action.name}, format=${job.format.name}, '
        'path=${job.inputPath}');
    _cancelRequested = false;
    emit(ArchiveProgress(0, _position));

    _progressCell = calloc<Int32>();
    _progressCell!.value = 0;
    _cancelCell = calloc<Int32>();
    _cancelCell!.value = 0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      final cell = _progressCell;
      if (cell == null) return;
      add(_ArchiveProgressUpdate(cell.value.clamp(0, 1000) / 1000.0));
    });

    _receivePort = ReceivePort();
    _receivePort!.listen((message) {
      if (message is ArchiveResult) {
        add(_ArchiveFinished(message));
      }
    });

    try {
      Isolate.spawn(
        ArchiveWorker.runArchive,
        ArchiveParams(
          action: job.action,
          inputPath: job.inputPath,
          outputPath: job.outputPath,
          format: job.format,
          level: _level,
          progressAddress: _progressCell!.address,
          cancelAddress: _cancelCell!.address,
          sendPort: _receivePort!.sendPort,
        ),
      );
      _workerActive = true;
    } catch (e) {
      add(_ArchiveFinished(ArchiveResult(success: false, error: e.toString())));
    }
  }

  QueuePosition get _position =>
      QueuePosition(currentIndex: _currentIndex + 1, total: _jobs.length);

  void _onArchiveProgressUpdate(
      _ArchiveProgressUpdate event, Emitter<ArchiveState> emit) {
    if (state is ArchiveProgress || state is ArchiveRunning) {
      emit(ArchiveProgress(event.fraction, _position));
    }
  }

  void _onCancelArchive(CancelArchive event, Emitter<ArchiveState> emit) {
    _queueCancelled = true;
    if (!_workerActive) {
      _disposeIdleResources();
      emit(_doneState());
      return;
    }
    _logger.info('Cancellation requested; signalling the archive worker.');
    _cancelRequested = true;
    _cancelCell?.value = 1;
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _onArchiveFinished(_ArchiveFinished event, Emitter<ArchiveState> emit) {
    final wasCancelled = _cancelRequested || event.result.cancelled;
    _cancelRequested = false;
    final job = _jobs[_currentIndex];
    _disposeIdleResources();

    if (wasCancelled) {
      _logger.info('Archive job cancelled; partial output removed.');
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
      _logger.severe('Archive job failed: ${event.result.error}');
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

  ArchiveBatchDone _doneState() {
    final duration = _startTime != null
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;
    _logger.info(
        'Archive queue finished: ${_results.successCount}/${_jobs.length} '
        'succeeded in ${duration.inMilliseconds}ms.');
    return ArchiveBatchDone(List.unmodifiable(_results), duration: duration);
  }

  void _disposeIdleResources() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _receivePort?.close();
    _receivePort = null;
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
      _cancelCell?.value = 1;
      _detachResources();
    } else {
      _disposeIdleResources();
    }
    return super.close();
  }
}
