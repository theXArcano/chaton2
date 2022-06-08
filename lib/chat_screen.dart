import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:chat2/chat_message.dart';
import 'package:chat2/text_composer.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final db = FirebaseFirestore.instance;
  final storage = FirebaseStorage.instance;

  User? _currentUser;

  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _currentUser = user;
      });
    });
  }

  Future<User?> getUser() async {
    if (_currentUser != null) return _currentUser;

    try {
      final GoogleSignInAccount? googleSignInAccount =
          await GoogleSignIn().signIn();

      final GoogleSignInAuthentication? googleSignInAuthentication =
          await googleSignInAccount?.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleSignInAuthentication?.idToken,
          accessToken: googleSignInAuthentication?.accessToken);

      final UserCredential authResult =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final User? user = authResult.user;

      return user;
    } catch (error) {
      return null;
    }
  }

  void _sendMsg({String? text, XFile? imgFile}) async {
    final User? user = await getUser();

    if (user == null) {
      scaffoldKey.currentState?.showSnackBar(const SnackBar(
        content:
            Text("Não foi possivel fazer o login. Tente novamente mais tarde!"),
      ));
    }

    Map<String, dynamic> data = {
      "uid": user?.uid,
      "senderName": user?.displayName,
      "senderPhotoUrl": user?.photoURL,
    };

    if (imgFile != null && text == null) {
      final task = storage
          .ref()
          .child(DateTime.now().millisecondsSinceEpoch.toString())
          .putFile(File(imgFile.path));

      task.then((p0) async => {
            db.collection("messages").get().then((value) async => db
                    .collection("messages")
                    .add({
                  ...data,
                  "id": (value.size + 1),
                  "imgUrl": await p0.ref.getDownloadURL()
                }))
          });
    }

    if (imgFile == null && text != null) {
      db.collection("messages").get().then((value) async => db
          .collection("messages")
          .add({...data, "id": (value.size + 1), "text": text}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          title: Text(_currentUser != null
              ? 'Olá, ${_currentUser!.displayName}'
              : 'Chat App'),
          centerTitle: true,
          elevation: 0,
          actions: <Widget>[
            _currentUser != null
                ? IconButton(
                    icon: Icon(Icons.exit_to_app),
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                      googleSignIn.signOut();
                      scaffoldKey.currentState?.showSnackBar(const SnackBar(
                          content: Text(
                              'Você deslogou do APP com sucesso!'))); //smackbar
                    })
                : Container()
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: db.collection("messages").orderBy("id").snapshots(),
                builder: (context, snapshot) {
                  switch (snapshot.connectionState) {
                    case ConnectionState.none:
                    case ConnectionState.waiting:
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    default:
                      List<DocumentSnapshot> documents =
                          snapshot.data!.docs.reversed.toList();

                      return ListView.builder(
                          itemCount: documents.length,
                          reverse: true,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: ChatMessage(
                                  documents[index].data()
                                      as Map<String, dynamic>,
                                  true),
                            );
                          });
                  }
                },
              ),
            ),
            TextComposer(_sendMsg),
          ],
        ));
  }
}
