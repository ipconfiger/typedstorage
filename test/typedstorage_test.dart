import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:typedstorage/src/storage.dart';


class MockCryptor implements ICryptable {
  static final Uint8List SECRET = Uint8List.fromList([0,1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,6,7,8,9,1,2]);
  static final Uint8List IV = Uint8List.fromList([1,2,3,4,5,6,7,8]);
  
  @override
  Future<Uint8List> process(Uint8List value) async {
    // Simple XOR encryption for testing purposes
    final result = Uint8List(value.length);
    for (int i = 0; i < value.length; i++) {
      result[i] = value[i] ^ SECRET[i % SECRET.length];
    }
    return result;
  }
}

class AType implements ISerializable{
  String? name;
  int? age;

  @override
  void deSerialize(Map<String, dynamic> value) {
    name = value['name'] as String?;
    age = value['age'] as int?;
  }

  @override
  Map<String, dynamic> serialize() {
    return {'name': name, 'age': age};
  }

  @override
  String toString() {
    return jsonEncode(this.serialize());
  }

}


void main() {
  test('test storage', () async{
    String file_path = "/Users/alex/Projects/workspace/typedstorage/test/mydb.json";

    if (await File(file_path).exists()) {
      File(file_path).deleteSync();
    }

    final encProcess = MockCryptor();
    final store = TypeStorage().init(file_path, cryptor: encProcess);
    await store.reload();

    store.setValue<String>('testKey1', "哈哈哈");
    store.setValue<int>('testKey2', 123123);
    print(store.getValue<String>('testKey1'));
    AType person = AType();
    person.name = "Alex";
    person.age=18;
    store.setObject('Person', person);

    await store.save();

    final p = store.getObject('Person', ()=>AType());
    print(p);

    final names = ['Bob', 'Alice', 'John', 'Celina', 'Eda', 'Meachle', 'Alex', 'Bill'];
    for (final name in names){
      final ps = AType();
      ps.name = name;
      ps.age=0;
      store.addToList<AType>(ps);
    }

    for (final pp in store.findType<AType>(where:(item) => item.name!.startsWith("A"), sort:(a, b) => a.name!.length.compareTo(b.name!.length), creator:() => AType())){
      print(pp);
    }

    await store.save();

    String namedKey = 'student';

    store.createNamedList(namedKey, () => AType());

    for (final name in names){
      final ps = AType();
      ps.name = name;
      ps.age=0;
      store.namedListAppend<AType>(namedKey, ps);
    }

    final first = store.namedListFirst<AType>(namedKey);
    expect(first!.name, names[0]);

    final ls = store.namedListQuery<AType>(namedKey, where: (item) => item.name!.startsWith('A'), sort: (a, b)=> a.age!.compareTo(b.age!));
    print('$ls');







  });
}
