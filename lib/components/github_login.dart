import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../utils/action.dart';
import '../config.dart';

const clientId = 'Ov23liiGDLj2Or7Mk7mi';
const scope = 'public_repo';
const repoAPI = 'https://api.github.com/repos/zytx121/je/issues';

/// https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow
class GitHubLogin extends StatefulWidget {
  const GitHubLogin({super.key});
  @override
  State<GitHubLogin> createState() => _GitHubLoginState();
}

class _GitHubLoginState extends State<GitHubLogin> {
  String _errorMessage = ''; // 显示信息

  int _step = 0;
  static const title = ["确认网络连接", "登录到Github", "登录成功"];

  bool _step1BtnClicked = false;
  late DeviceAuth _deviceAuth;

  bool _step2Btn1Clicked = false;
  bool _step2Btn2Clicked = false;

  DateTime? _loginStartTime;
  final ValueNotifier<int> _countdown = ValueNotifier<int>(0);
  Timer? expireTimer;

  DateTime? _lastPollTime;

  @override
  void dispose() {
    _countdown.dispose();
    expireTimer?.cancel();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      _errorMessage = '';
      switch (_step) {
        case 0:
          _step = 1;
          _step1BtnClicked = false;
          break;
        case 1:
          _step = 2;
          _step2Btn1Clicked = false;
          break;
        default:
          Navigator.of(context).pop();
          break;
      }
    });
  }

  void _restart() {
    setState(() {
      // 不清空errorMessage
      _step = 0;
      _step1BtnClicked = false;
      _step2Btn1Clicked = false;
      _step2Btn2Clicked = false;

      _countdown.value = 0;
      _expireCountDown(false);
      _loginStartTime = null;

      _lastPollTime = null;
    });
  }

  void _onTimeOver() {
    _errorMessage = '设备码已过期，请重新登录';
    _restart();
  }

  /// 启动/暂停 有效期倒计时
  /// 支持中断后重新开始
  /// 在step1->2时调用。当后台时停止，前台时恢复
  void _expireCountDown([bool begin = true]) {
    expireTimer?.cancel();
    if (!begin || _loginStartTime == null) return;
    _countdown.value =
        _deviceAuth.expiresIn -
        DateTime.now().difference(_loginStartTime!).inSeconds;
    expireTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final newValue =
          _deviceAuth.expiresIn -
          DateTime.now().difference(_loginStartTime!).inSeconds;
      if (newValue > 0) {
        _countdown.value = newValue;
      } else {
        _countdown.value = 0;
        timer.cancel();
        _onTimeOver();
      }
    });
  }

  bool get _canPoll => _countdown.value > 0 && _step == 1;

  /// 查询一次登录状态 管理间隔与状态
  /// 轮询结束则返回false 可以继续轮询则返回true
  Future<void> _query() async {
    if (_countdown.value <= 0) {
      _onTimeOver();
      return;
    }
    if (_canPoll == false) return;
    // 等待至少间隔时间
    final now = DateTime.now();
    if (_lastPollTime != null) {
      final dt = now.difference(_lastPollTime!);
      _lastPollTime = now; // 防止多次点击，必须在等待前更新
      if (dt < _deviceAuth.interval) {
        await Future.delayed(_deviceAuth.interval - dt);
      }
    } else {
      _lastPollTime = now;
    }
    // 查询登录状态
    late final http.Response tRes;
    try {
      if (_canPoll == false) return;
      tRes = await http
          .post(
            Uri.parse('https://github.com/login/oauth/access_token'),
            headers: {'Accept': 'application/json'},
            body: {
              'client_id': clientId,
              'device_code': _deviceAuth.deviceCode,
              'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
            },
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      setState(() {
        _errorMessage = '查询失败: ${e.toString()}\n这可能是网络问题，请重试';
        _step2Btn1Clicked = true;
        _step2Btn2Clicked = false;
      });
      return;
    }
    final t = jsonDecode(tRes.body);
    if (t.containsKey('access_token')) {
      expireTimer?.cancel();
      Config.githubToken = t['access_token']; // setter触发获取头像等
      _nextStep();
      return;
    }
    switch (t['error']) {
      case 'authorization_pending':
        setState(() {
          _errorMessage = '等待用户授权中...\n(疑似……您还没授权?)';
          _step2Btn1Clicked = true;
          _step2Btn2Clicked = false;
        });
        return;
      case 'slow_down':
        await Future.delayed(const Duration(seconds: 5));
        setState(() {
          _errorMessage = '等待用户授权中...\n此外你点击得太频繁啦！';
          _step2Btn1Clicked = true;
          _step2Btn2Clicked = false;
        });
        return;
      case 'expired_token':
        _onTimeOver();
        return;
      case 'access_denied':
        _errorMessage = '用户拒绝授权，请重新登录';
        _restart();
        return;
      case 'incorrect_device_code':
        setState(() {
          _errorMessage = '设备码错误，请重新授权';
          _step2Btn1Clicked = false;
          _step2Btn2Clicked = false;
        });
        return;
      case 'unsupported_grant_type':
      case 'incorrect_client_credentials':
      case 'device_flow_disabled':
      default:
        setState(() {
          expireTimer?.cancel();
          _errorMessage = '查询成功，但服务器报错: ${t['error']}\n这可能是个bug，请联系开发者';
          _step2Btn1Clicked = false;
          _step2Btn2Clicked = false;
        });
        return;
    }
  }

  //// 以下是视图 ////
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title[_step])),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_step == 0) _buildStep1(context),
            if (_step == 1) _buildStep2(context),
            if (_step == 2) _buildStep3(context),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    if (_errorMessage.isEmpty) return const SizedBox.shrink();
    return Text(
      _errorMessage,
      style: const TextStyle(color: Colors.red),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStep1(BuildContext context) {
    final Widget step1to2UI;
    if (_step1BtnClicked) {
      step1to2UI = const Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(),
      );
    } else {
      step1to2UI = ElevatedButton(
        onPressed: () {
          if (_step1BtnClicked) return;
          setState(() {
            _step1BtnClicked = true;
            _errorMessage = '';
          });
          DeviceAuth.fromGithub()
              .then((deviceAuth) {
                _deviceAuth = deviceAuth;
                // 记录登录开始时间
                _loginStartTime = DateTime.now();
                // 启动倒计时
                _expireCountDown(true);
                _nextStep();
              })
              .catchError((e) {
                setState(() {
                  expireTimer?.cancel();
                  _errorMessage = '错误: ${e.toString()}\n请检查网络连接';
                  _step1BtnClicked = false;
                });
              });
        },
        child: const Text('开始登录'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('下面将登录到GitHub', style: Theme.of(context).textTheme.headlineMedium),
        const Text(
          '请保持网络畅通 (大陆内可能需要VPN)\n为了保证安全，我们使用设备码登录',
          textAlign: TextAlign.center,
        ),
        step1to2UI,
        _buildError(context),
      ],
    );
  }

  Widget _buildStep2(BuildContext context) {
    final Widget step2to3UI;
    if (_step2Btn1Clicked) {
      final Widget queryBtn;
      if (_step2Btn2Clicked) {
        queryBtn = const Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        );
      } else {
        queryBtn = ElevatedButton(
          onPressed: () {
            setState(() {
              _errorMessage = '';
              _step2Btn2Clicked = true;
            });
            _query().whenComplete(() {
              setState(() {
                _step2Btn2Clicked = false;
              });
            });
          },
          child: const Text('授权完毕? 点我'),
        );
      }
      step2to3UI = Column(
        children: [
          const Text('没有自动打开浏览器? 请手动打开以下链接:'),
          GestureDetector(
            onTap: () {
              Clipboard.setData(
                ClipboardData(text: _deviceAuth.verificationUri),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('链接已复制'),
                  duration: Duration(milliseconds: 1500),
                ),
              );
            },
            child: Text(
              _deviceAuth.verificationUri,
              style: const TextStyle(
                fontSize: 12,
                decoration: TextDecoration.underline,
                color: Colors.blue,
              ),
            ),
          ),
          queryBtn,
        ],
      );
    } else {
      step2to3UI = ElevatedButton(
        onPressed: () async {
          if (_step2Btn1Clicked) return;
          setState(() {
            _step2Btn1Clicked = true;
          });
          try {
            await launchUrlWrap(
              _deviceAuth.verificationUri,
              LaunchMode.externalApplication,
            );
          } catch (e) {
            setState(() {
              _errorMessage = '打开浏览器失败: ${e.toString()}\n请手动打开链接';
            });
            return;
          }
        },
        child: Text('登录并输入设备码'),
      );
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('设备码: '),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: '复制设备码',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _deviceAuth.userCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('设备码已复制'),
                    duration: Duration(milliseconds: 1500),
                  ),
                );
              },
            ),
          ],
        ),
        Text(
          _deviceAuth.userCode,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        step2to3UI,
        _buildError(context),
        ValueListenableBuilder<int>(
          valueListenable: _countdown,
          builder: (context, value, child) {
            return Text('设备码有效期: ${value}s');
          },
        ),
      ],
    );
  }

  Widget _buildStep3(BuildContext context) {
    return Column(
      children: [
        Text('登录成功！', style: Theme.of(context).textTheme.headlineMedium),
        ElevatedButton(onPressed: _nextStep, child: const Text('点我关闭页面')),
      ],
    );
  }
}

class DeviceAuth {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int expiresIn;
  final Duration interval;

  DeviceAuth({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  static Future<DeviceAuth> fromGithub() async {
    final dRes = await http
        .post(
          Uri.parse('https://github.com/login/device/code'),
          headers: {'Accept': 'application/json'},
          body: {'client_id': clientId, 'scope': scope},
        )
        .timeout(const Duration(seconds: 15));

    if (dRes.statusCode != 200) {
      throw Exception('获取设备码失败：${dRes.statusCode} ${dRes.body}');
    }
    final d = jsonDecode(dRes.body);
    return DeviceAuth(
      deviceCode: d['device_code'],
      userCode: d['user_code'],
      verificationUri: d['verification_uri'],
      expiresIn: d['expires_in'],
      interval: Duration(milliseconds: d['interval'] * 1000 + 300),
    );
  }
}

Future<http.Response> createIssue(String token, String title, String body) {
  return http.post(
    Uri.parse(repoAPI),
    headers: {
      'Authorization': 'token $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'title': title, 'body': body}),
  );
}

class UserInfo {
  late final String login;
  late final String name;
  late final String avatarUrl;

  UserInfo({required this.login, required this.name, required this.avatarUrl});

  static Future<UserInfo> fromGithub(String token) async {
    /// https://docs.github.com/zh/rest/users/users?apiVersion=2022-11-28#get-the-authenticated-user
    final response = await http.get(
      Uri.parse('https://api.github.com/user'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UserInfo(
        login: data['login'],
        name: data['name'] ?? '',
        avatarUrl: data['avatar_url'] ?? '',
      );
    } else {
      throw Exception('获取用户信息失败：${response.statusCode} ${response.body}');
    }
  }

  UserInfo.fromJson(String json) {
    final data = jsonDecode(json);
    login = data['login'];
    name = data['name'] ?? '';
    avatarUrl = data['avatar_url'] ?? '';
  }

  String toJson() {
    return jsonEncode({'login': login, 'name': name, 'avatar_url': avatarUrl});
  }
}
