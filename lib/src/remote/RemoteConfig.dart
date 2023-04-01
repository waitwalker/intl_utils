///
/// Created by hai046 on 2022/7/9.
///

abstract class RemoteConfig {
  Map<String, dynamic> get messages;

  Future<void> config();

  ///实现一个通过key获取value的返回
  dynamic operator [](String messageName) => messages[messageName];
}
