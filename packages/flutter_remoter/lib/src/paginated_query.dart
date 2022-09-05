import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/flutter_remoter.dart';
import 'package:remoter/remoter.dart';

class PaginatedRemoterQuery<T> extends StatefulWidget {
  final String remoterKey;
  final FutureOr<T> Function(RemoterParam?) execute;
  final Widget Function(
    BuildContext,
    PaginatedRemoterData<T>,
    RemoterPaginatedUtils utils,
  ) builder;
  final Function(
          PaginatedRemoterData<T> oldState, PaginatedRemoterData<T> newState)?
      listener;
  final dynamic Function(List<T>)? getNextPageParam;
  final dynamic Function(List<T>)? getPreviousPageParam;
  final RemoterClientOptions? options;
  const PaginatedRemoterQuery({
    super.key,
    this.getPreviousPageParam,
    this.getNextPageParam,
    this.options,
    this.listener,
    required this.remoterKey,
    required this.execute,
    required this.builder,
  });

  @override
  State<PaginatedRemoterQuery<T>> createState() =>
      _PaginatedRemoterQueryState<T>();
}

class _PaginatedRemoterQueryState<T> extends State<PaginatedRemoterQuery<T>> {
  StreamSubscription<PaginatedRemoterData<T>>? subscription;
  late PaginatedRemoterData<T> data;
  late RemoterPaginatedUtils<PaginatedRemoterData<T>> utils;

  RemoterPaginatedUtils<PaginatedRemoterData<T>> processUtils() {
    final remoter = RemoterProvider.of(context);
    return RemoterPaginatedUtils<PaginatedRemoterData<T>>(
      fetchNextPage: () => remoter.client.fetchNextPage<T>(widget.remoterKey),
      fetchPreviousPage: () =>
          remoter.client.fetchPreviousPage<T>(widget.remoterKey),
      invalidateQuery: () =>
          remoter.client.invalidateQuery<T>(widget.remoterKey),
      retry: () => remoter.client.retry<T>(widget.remoterKey),
      setData: (data) => remoter.client
          .setData<PaginatedRemoterData<T>>(widget.remoterKey, data),
    );
  }

  PaginatedRemoterData<T> startStream() {
    subscription?.cancel();
    final provider = RemoterProvider.of(context);
    provider.client.savePaginatedQueryFunctions(
      widget.remoterKey,
      PaginatedQueryFunctions<T>(
        getPreviousPageParam: widget.getPreviousPageParam,
        getNextPageParam: widget.getNextPageParam,
      ),
    );
    provider.client.fetchPaginated<T>(
      widget.remoterKey,
      widget.execute,
      widget.options?.staleTime,
    );
    subscription = provider.client
        .getStream<PaginatedRemoterData<T>, T>(
            widget.remoterKey, widget.options?.cacheTime)
        .listen((event) {
      if (widget.listener != null) widget.listener!(data, event);
      setState(() {
        data = event;
      });
    });
    return provider.client
            .getData<PaginatedRemoterData<T>>(widget.remoterKey) ??
        PaginatedRemoterData<T>(
          key: widget.remoterKey,
          data: null,
          pageParams: null,
          status: RemoterStatus.fetching,
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (subscription != null) return;
    data = startStream();
    utils = processUtils();
  }

  @override
  void didUpdateWidget(PaginatedRemoterQuery<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newData = startStream();
    final newUtils = processUtils();
    setState(() {
      data = newData;
      utils = newUtils;
    });
  }

  @override
  void dispose() {
    super.dispose();
    subscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, data, utils);
  }
}
