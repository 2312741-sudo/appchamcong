import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final storesSnap = await FirebaseFirestore.instance.collection('stores').get();
  for (var store in storesSnap.docs) {
    print('Store: ${store.id}');
    final membersSnap = await store.reference.collection('members').get();
    for (var member in membersSnap.docs) {
      print(' - Member: ${member.id} status: ${member.data()['status']}');
    }
  }
}
