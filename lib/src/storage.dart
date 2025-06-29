import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

abstract class ISerializable {
  Map<String, dynamic> serialize();
  void deSerialize(Map<String, dynamic> value);
}

abstract class ICryptable {
  Future<Uint8List> process(Uint8List value);
}

class TypeStorage {

  static final TypeStorage _singleton = TypeStorage._internal();

  factory TypeStorage() {
    return _singleton;
  }

  TypeStorage._internal();

  String? filePath;

  ICryptable? cryptor;

  TypeStorage init(String storageFilepath, {ICryptable? cryptor}){
    this.cryptor = cryptor;
    Timer.periodic(const Duration(seconds: 10), (timer) async{
      await this.save();
    });
    if (inited){
      return this;
    }else {
      filePath = storageFilepath;
      inited = true;
      return this;
    }
  }

  bool inited = false;

  Map<String, dynamic>? coreStorage;
  String? serialized;
  Map<String, dynamic> namedListsKeys = <String, dynamic>{};
  Map<String, dynamic> namedListsType = <String, dynamic>{};

  Future<void> reload() async {
    if (filePath == null) {
      throw StateError('TypeStorage not initialized. Call init() first.');
    }
    File file = File(filePath!);
    if (await file.exists()) {
      final String savedStr = await file.readAsString();
      if (savedStr.startsWith('encrypted:')){
        if (cryptor == null) {
          throw StateError('Encrypted data found but no cryptor provided.');
        }
        final b64str = savedStr.substring(10);
        final rawBytes = await cryptor!.process(base64Decode(b64str));
        serialized = utf8.decode(rawBytes.toList());
      }else{
        serialized=savedStr;
      }
      if (serialized!.isEmpty){
        coreStorage = <String, dynamic>{};
      }else {
        coreStorage = jsonDecode(serialized!) as Map<String, dynamic>;
      }
    }else{
      coreStorage = <String, dynamic>{};
    }
  }

  Future<void> save() async {
    if (filePath == null || coreStorage == null) {
      throw StateError('TypeStorage not initialized. Call init() first.');
    }
    final current = jsonEncode(coreStorage);
    if (current!=serialized){
      File file = File(filePath!);
      final writer = file.openWrite();
      serialized = current;
      String storedStr;
      if (cryptor!=null){
        storedStr = "encrypted:" + base64Encode((await cryptor!.process(Uint8List.fromList(utf8.encode(serialized!)))).toList());
      }else{
        storedStr = serialized!;
      }
      writer.add(utf8.encode(storedStr));
      await writer.close();
    }
  }

  bool createNamedList<T>(String name, T Function() creator){
    assert(!this.namedListsKeys.containsKey(name));
    assert(!this.namedListsType.containsKey(name));
    this.namedListsKeys[name] = creator;
    this.namedListsType[name] = T.toString();
    coreStorage!["NAMED_LIST:$name"] = <Map<String, dynamic>>[];
    return true;
  }

  bool deleteNamedList(String name){
    assert(this.namedListsKeys.containsKey(name));
    assert(this.namedListsType.containsKey(name));
    this.namedListsKeys.remove(name);
    this.namedListsType.remove(name);
    this.coreStorage!.remove("NAMED_LIST:$name");
    return true;
  }

  void namedListAppend<T extends ISerializable>(String name, T item){
    assert(this.namedListsKeys.containsKey(name));
    assert(this.namedListsType.containsKey(name));
    assert(this.namedListsType[name] == T.toString());
    final List<dynamic> list = coreStorage!["NAMED_LIST:$name"] as List<dynamic>;
    list.add(item.serialize());
    coreStorage!["NAMED_LIST:$name"] = list;
  }

  List<T> namedListAll<T extends ISerializable>(String name){
    assert(this.namedListsKeys.containsKey(name));
    assert(this.namedListsType.containsKey(name));
    assert(this.namedListsType[name] == T.toString());
    final creator = this.namedListsKeys[name] as T Function();
    final List<dynamic> list = coreStorage!["NAMED_LIST:$name"] as List<dynamic>;
    List<T> results = <T>[];
    for (final Map<String, dynamic> item in list){
      final obj = creator();
      obj.deSerialize(item);
      results.add(obj);
    }
    return results;
  }

  List<T> namedListQuery<T extends ISerializable>(String name, {required bool Function(T) where, int Function(T, T)? sort, Function()? creator}){
    List<T> namedList = namedListAll<T>(name);
    if (sort != null) {
      namedList.sort(sort);
    }
    return namedList.where(where).toList();
  }

  T? namedListFirst<T extends ISerializable>(String name){
    assert(this.namedListsKeys.containsKey(name));
    assert(this.namedListsType.containsKey(name));
    assert(this.namedListsType[name] == T.toString());
    final creator = this.namedListsKeys[name] as T Function();
    final List<dynamic> list = coreStorage!["NAMED_LIST:$name"] as List<dynamic>;
    if(list.isNotEmpty){
      final obj = creator();
      obj.deSerialize(list[0] as Map<String, dynamic>);
      return obj;
    }
    return null;
  }

  void namedListRemoveAt<T extends ISerializable>(String name, int index){
    assert(this.namedListsKeys.containsKey(name));
    assert(this.namedListsType.containsKey(name));
    assert(this.namedListsType[name] == T.toString());
    final List<dynamic> list = coreStorage!["NAMED_LIST:$name"] as List<dynamic>;
    list.removeAt(index);
    coreStorage!["NAMED_LIST:$name"] = list;
  }

  void nameListUpdateAt<T extends ISerializable>(String name, int index, T item){
    assert(this.namedListsKeys.containsKey(name));
    assert(this.namedListsType.containsKey(name));
    assert(this.namedListsType[name] == T.toString());
    final List<dynamic> list = coreStorage!["NAMED_LIST:$name"] as List<dynamic>;
    list[index] = item.serialize();
    coreStorage!["NAMED_LIST:$name"] = list;
  }

  void namedListKeepWhere<T extends ISerializable>(String name, {required bool Function(T) where}){
    final List<T> typedList = this.namedListAll<T>(name);
    final List<T> newList = typedList.where(where).toList();
    final resultList = <Map<String, dynamic>>[];
    for (final item in newList){
      resultList.add(item.serialize());
    }
    coreStorage!["NAMED_LIST:$name"] = resultList;
  }


  void setValue<T>(String key, T value){
    coreStorage![key] = value;
  }

  T? getValue<T>(String key){
    return coreStorage![key] as T?;
  }

  void setObject(String key, ISerializable value){
    coreStorage![key] = value.serialize();
  }

  T? getObject<T extends ISerializable>(String key, T Function() creator){
    final data = coreStorage![key];
    if (data == null) return null;
    final obj = creator();
    obj.deSerialize(data as Map<String, dynamic>);
    return obj;
  }

  void addToList<T extends ISerializable>(T value){
    final List<dynamic> list = (coreStorage!["LIST:" + T.toString()] ?? <dynamic>[]) as List<dynamic>;
    list.add(value.serialize());
    coreStorage!["LIST:" + T.toString()] = list;
  }

  T? listPosition<T extends ISerializable>(int position, T Function() creator) {
    final List<dynamic> list = (coreStorage!["LIST:" + T.toString()] ?? <dynamic>[]) as List<dynamic>;
    if (position >= list.length){
      return null;
    }
    final T obj = creator();
    obj.deSerialize(list[position] as Map<String, dynamic>);
    return obj;
  }

  void removeAt<T extends ISerializable>(int position){
    final List<dynamic> list = (coreStorage!["LIST:" + T.toString()] ?? <dynamic>[]) as List<dynamic>;
    if ( position >= list.length || position < 0) {
      throw RangeError.index(position, list);
    }
    list.removeAt(position);
    coreStorage!["LIST:" + T.toString()]  = list;
  }

  void updateAt<T extends ISerializable>(int position, T item){
    final List<dynamic> list = (coreStorage!["LIST:" + T.toString()] ?? <dynamic>[]) as List<dynamic>;
    if ( position >= list.length || position < 0) {
      throw RangeError.index(position, list);
    }
    list[position] = item.serialize();
    coreStorage!["LIST:" + T.toString()]  = list;
  }

  List<T> listAll<T extends ISerializable>(T Function() creator) {
    final List<dynamic> list = (coreStorage!["LIST:" + T.toString()] ?? <dynamic>[]) as List<dynamic>;
    final List<T> typedList = <T>[];
    for (final map in list){
      final obj = creator();
      obj.deSerialize(map as Map<String, dynamic>);
      typedList.add(obj);
    }
    return typedList;
  }

  List<T> findType<T extends ISerializable>({required bool Function(T) where, int Function(T, T)? sort, T Function()? creator}){
    if (creator == null) {
      throw ArgumentError('Creator function is required for findType');
    }
    final List<T> typedList = this.listAll<T>(creator);
    if (sort != null) {
      typedList.sort(sort);
    }
    return typedList.where(where).toList();
  }

  T? listFirst<T extends ISerializable>(T Function() creator){
    final List<dynamic> list = (coreStorage!["LIST:" + T.toString()] ?? <dynamic>[]) as List<dynamic>;
    if (list.isNotEmpty){
      final obj = creator();
      obj.deSerialize(list[0] as Map<String, dynamic>);
      return obj;
    }
    return null;
  }

}