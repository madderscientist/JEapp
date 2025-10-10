import 'dart:convert';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../components/detail.dart';

/// 请求github的newest issues接口
class IssueRequester {
  // 1000为谱库曲谱数量规模 用以保证有下一页 如果无法预估则用0
  static const int resultScale = 1000;
  static const String baseUrl =
      "https://api.github.com/repos/zytx121/je/issues";
  final http.Client? client;  // 外部传入，外部管理
  String _nextUrl = "";
  int perPage;
  int issueNumber = -1; // 记录总共请求了多少个issues -1表示没开始 用以兼容resultScale=0的情况
  bool isLoading = false;

  IssueRequester({this.perPage = 10, this.client});

  int get pageNext => (issueNumber ~/ perPage) + 1;
  bool get hasNext => _nextUrl.isNotEmpty || issueNumber < resultScale;

  /// 用原始页数请求（已请求数小于resultScale时的保底）
  String makeUrl() {
    String url = baseUrl;
    if (url.endsWith('?') || url.endsWith('&')) {
      return "${url}per_page=$perPage&page=$pageNext";
    }
    final separator = url.contains('?') ? '&' : '?';
    return "$url${separator}per_page=$perPage&page=$pageNext";
  }

  /// 从响应头中解析出下一页的链接
  /// 如果没有下一页，返回null
  /// https://docs.github.com/en/rest/using-the-rest-api/getting-started-with-the-rest-api?apiVersion=2022-11-28#about-the-response-code-and-headers
  static String? nextPageUrl(http.Response response) {
    final linkHeader = response.headers['link'];
    if (linkHeader != null) {
      final links = linkHeader.split(',');
      for (var link in links) {
        if (link.contains('rel="next"')) {
          int start = link.indexOf('<') + 1;
          return link.substring(start, link.indexOf('>', start));
        }
      }
    }
    return null;
  }

  Future<List<RawScore>> fetchIssues({bool reset = false}) async {
    if (isLoading) throw StateError("在找了在找了 (/ﾟДﾟ)/");
    if (reset) {
      issueNumber = -1;
      _nextUrl = "";
    }
    if (!hasNext) throw StateError("没有更多啦 ╮(๑•́ ₃•̀๑)╭");
    if (issueNumber < 0) issueNumber = 0;
    isLoading = true;
    final String url = _nextUrl.isEmpty ? makeUrl() : _nextUrl;
    final http.Response response;
    try {
      if (client == null) {
        response = await http.get(Uri.parse(url));
      } else {
        response = await client!.get(Uri.parse(url));
      }
    } catch (e) {
      if (issueNumber == 0) issueNumber = -1;
      isLoading = false;
      throw Exception("网络请求失败了 ╥﹏╥");
    }
    isLoading = false;

    if (response.statusCode != 200) {
      if (response.statusCode == 403) {
        throw Exception("请求超额度了 ╥﹏╥");
      }
      throw Exception("网络请求失败了 ╥﹏╥");
    }

    // 获取下一页的链接，因为page大了会请求失败
    _nextUrl = IssueRequester.nextPageUrl(response) ?? "";

    final List<dynamic> issueList = jsonDecode(utf8.decode(response.bodyBytes));
    final result = RawScore.parseGithub(issueList);
    issueNumber += result.length;
    return result;
  }
}

class ScoreSearcher {
  static Future<List<RawScore>> github(String keyword) async {
    String? url =
        'https://api.github.com/search/issues?q=$keyword+state:open+repo:zytx121/je';
    List<RawScore> result = [];
    while (url != null) {
      // 如有分页，一次性请求完
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        if (response.statusCode == 403) {
          throw Exception("请求超额度了 ╥﹏╥");
        }
        throw Exception("网络请求失败了 ╥﹏╥");
      }
      final Map<String, dynamic> data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      final scores = data['items'] as List<dynamic>;
      result.addAll(RawScore.parseGithub(scores));
      url = IssueRequester.nextPageUrl(response);
    }
    return result;
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
