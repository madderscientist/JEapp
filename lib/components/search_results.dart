import 'package:flutter/material.dart';
import '../utils/score_request.dart';

class SearchResultsList extends StatefulWidget {
  final Future<List<RawScore>> request;
  final String title;
  const SearchResultsList({
    super.key,
    required this.request,
    required this.title,
  });

  @override
  State<SearchResultsList> createState() => _SearchResultsListState();
}

class _SearchResultsListState extends State<SearchResultsList> {
  // scores=[]: 无结果; scores=null: 正在加载; failed!=null: 加载失败
  List<RawScore>? scores;
  String? failed;
  late double _finalWidth;

  @override
  void initState() {
    super.initState();
    widget.request
        .then((value) {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => scores = value);
        })
        .catchError((error) {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => failed = error.toString());
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _finalWidth = MediaQuery.of(context).size.width * 0.5;
    if (_finalWidth > 500) _finalWidth = 500;
  }

  Widget _inner(BuildContext context) {
    if (failed != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/error.png', width: _finalWidth),
            Text(failed!, style: TextStyle(fontSize: 16, color: Colors.red)),
          ],
        ),
      );
    }
    if (scores == null) {
      return Center(child: CircularProgressIndicator());
    }
    if (scores!.isEmpty) {
      return Center(
        child: Image.asset('assets/noresult.png', width: _finalWidth),
      );
    }
    return ListView.builder(
      itemCount: scores!.length,
      itemBuilder: (context, index) => scores![index].toTitleCard(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _inner(context),
    );
  }
}
