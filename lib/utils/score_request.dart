import 'dart:convert';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../components/detail.dart';

/// 请求github的newest issues接口
class IssueRequester {
  static const String baseUrl =
      "https://api.github.com/repos/zytx121/je/issues";
  final http.Client _client;
  String _nextUrl = "";
  int perPage;
  int issueNumber = 0; // 记录总共请求了多少个issues
  bool isLoading = false;

  IssueRequester({this.perPage = 10}) : _client = http.Client();

  int get pageNext => (issueNumber ~/ perPage) + 1;
  bool get hasNext => _nextUrl.isNotEmpty || issueNumber < 1000;

  Future<List<RawScore>> fetchIssues({bool reset = false}) async {
    if (isLoading) throw StateError("在找了在找了 (/ﾟДﾟ)/");

    if (reset) {
      issueNumber = 0;
      _nextUrl = "";
    }
    if (!hasNext) throw StateError("没有更多啦 ╮(๑•́ ₃•̀๑)╭");

    isLoading = true;
    final String url = _nextUrl.isEmpty
        ? "$baseUrl?per_page=$perPage&page=$pageNext"
        : _nextUrl;
    final http.Response response;
    try {
      response = await _client.get(Uri.parse(url));
    } catch (e) {
      isLoading = false;
      throw Exception("网络请求失败了 ╥﹏╥");
    }
    isLoading = false;

    if (response.statusCode != 200) {
      throw Exception("网络请求失败了 ╥﹏╥");
    }

    final List<dynamic> issueList = jsonDecode(utf8.decode(response.bodyBytes));

    // 获取下一页的链接，因为page大了会请求失败
    // https://docs.github.com/en/rest/using-the-rest-api/getting-started-with-the-rest-api?apiVersion=2022-11-28#about-the-response-code-and-headers
    final linkHeader = response.headers['link'];
    _nextUrl = "";
    if (linkHeader != null) {
      final links = linkHeader.split(',');
      for (var link in links) {
        if (link.contains('rel="next"')) {
          int start = link.indexOf('<') + 1;
          _nextUrl = link.substring(start, link.indexOf('>', start));
          break;
        }
      }
    }

    final result = RawScore.parseGithub(issueList);
    issueNumber += result.length;
    return result;
  }

  void dispose() {
    _client.close();
  }
}

class ScoreSearcher {
  static Future<List<RawScore>> github(String keyword) async {
    final url =
        'https://api.github.com/search/issues?q=$keyword+state:open+repo:zytx121/je';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception("网络请求失败了 ╥﹏╥");
    }

    final Map<String, dynamic> data = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    final scores = data['items'] as List<dynamic>;
    return RawScore.parseGithub(scores);
  }

  static Future<List<RawScore>> acgmuse(String keyword) async {
    final url =
        'https://www.acgmuse.com/api/discussions?include=mostRelevantPost&filter%5Bq%5D=$keyword';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception("网络请求失败了 ╥﹏╥");
    }

    final Map<String, dynamic> data = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    return RawScore.parseAcgmuse(data);
  }
}

class RawScore {
  final String title;
  final String user;
  final String time;
  final String raw;

  RawScore({
    required this.title,
    required this.user,
    required this.time,
    required this.raw,
  });

  static List<RawScore> parseGithub(List<dynamic> rawIssueList) {
    List<RawScore> result = [];
    for (var issue in rawIssueList) {
      if (issue is Map<String, dynamic>) {
        result.add(
          RawScore(
            title: issue['title'] ?? '',
            user: issue['user']?['login'] ?? '',
            time: issue['created_at'] ?? '',
            raw: issue['body'] ?? '',
          ),
        );
      }
    }
    return result;
  }

  static List<RawScore> parseAcgmuse(Map<String, dynamic> rawScoreList) {
    List<RawScore> result = [];
    final details = rawScoreList['included'] as List<dynamic>;
    final titles = rawScoreList['data'] as List<dynamic>;
    for (var i = 0; i < details.length; i++) {
      result.add(
        RawScore(
          title: titles[i]['attributes']['title'] ?? '',
          user: 'Acgmuse用户',
          time: titles[i]['attributes']['createdAt'] ?? '',
          raw: details[i]['attributes']['contentHtml'] ?? '', // md解析器能兼容内嵌html
        ),
      );
    }
    return result;
  }

  Widget toTitleCard(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(15));
    final inner = OpenContainer(
      transitionDuration: const Duration(milliseconds: 450),
      transitionType: ContainerTransitionType.fade,
      openBuilder: (context, _) =>
          Detail(title: title, raw: raw, local: null, user: user, time: time),
      openElevation: 6,
      closedElevation: 4,
      closedShape: RoundedRectangleBorder(borderRadius: borderRadius),
      closedColor: Colors.white,
      closedBuilder: (context, openContainer) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
    // container主要是margin，其他卡片样式被OpenContainer承担了
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: Config.searchBarPadding * 1.6,
        vertical: 7,
      ),
      child: inner,
    );
  }
}
