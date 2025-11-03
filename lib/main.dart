import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ISG Assist',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Roboto',
      ),
      home: const MyHomePage(title: 'ISG Assist'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts flutterTts = FlutterTts();
  TextEditingController textController = TextEditingController();
  ScrollController scrollController = ScrollController();
  List<Message> messages = [];
  bool isListening = false;
  bool isLoading = false;
  bool isVoiceOutput = true;
  late AnimationController _animationController;
  late Animation<double> _animation;

  final List<String> suggestions = [
    "About ISG",
    "Campus Location",
    "Do you offer scholarships?",
    "How do I contact the school?",
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    // Add welcome message on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        messages.add(Message(
          text: "Hello! I’m ISG Assist 🤖. How may I help you today?",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    });
  }

  void startListening() async {
    bool available = await speech.initialize();
    if (available) {
      setState(() {
        isListening = true;
        _animationController.forward();
      });
      speech.listen(onResult: (result) {
        setState(() {
          textController.text = result.recognizedWords;
        });
        if (result.finalResult) {
          stopListening();
          queryDialogflow(result.recognizedWords);
        }
      });
    }
  }

  void stopListening() {
    if (isListening) {
      speech.stop();
      setState(() {
        isListening = false;
        _animationController.reverse();
      });
    }
  }

  Future<String> getAccessToken() async {
    try {
      final String jsonString = await rootBundle.loadString("assets/credentials.json");
      final jsonCredentials = json.decode(jsonString);
      final credentials = ServiceAccountCredentials.fromJson(jsonCredentials);
      final client = await clientViaServiceAccount(credentials, ['https://www.googleapis.com/auth/cloud-platform']);
      return client.credentials.accessToken.data;
    } catch (e) {
      throw Exception("Authentication error. Check credentials.json");
    }
  }

  void queryDialogflow(String userInput) async {
    if (userInput.trim().isEmpty) return;

    setState(() {
      messages.add(Message(text: userInput, isUser: true, timestamp: DateTime.now()));
      textController.clear();
      stopListening();
      isLoading = true;
    });
    scrollToBottom();

    try {
      final accessToken = await getAccessToken();
      final String projectId = "garbajohn-dialogflow-9qth";
      final String sessionId = "user123-session";
      final String url = "https://dialogflow.googleapis.com/v2/projects/$projectId/agent/sessions/$sessionId:detectIntent";

      final Map<String, dynamic> requestPayload = {
        "query_input": {
          "text": {
            "text": userInput,
            "language_code": "en"
          }
        }
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
        body: json.encode(requestPayload),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        String aiResponse = jsonResponse["queryResult"]["fulfillmentText"] ?? "No response";

        setState(() {
          messages.add(Message(text: aiResponse, isUser: false, timestamp: DateTime.now()));
          isLoading = false;
        });
        scrollToBottom();

        if (isVoiceOutput) {
          await flutterTts.speak(aiResponse);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void sendMessage() {
    final input = textController.text.trim();
    if (input.isNotEmpty) {
      queryDialogflow(input);
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    speech.stop();
    flutterTts.stop();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          Switch(
            value: isVoiceOutput,
            onChanged: (val) => setState(() => isVoiceOutput = val),
            activeColor: Colors.white,
          ),
        ],
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: messages.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {


                //modified this


                if (index == messages.length && isLoading) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: TypingIndicator(), // <- 👈 this is the new animated widget
                    ),
                  );
                }

                return MessageWidget(message: messages[index]);
              },
            ),
          ),
          if (suggestions.isNotEmpty)
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: suggestions.map((suggestion) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text(suggestion, style: const TextStyle(color: Colors.white)),
                      onPressed: () => queryDialogflow(suggestion),
                      backgroundColor: const Color(0xFF2ABBA7),
                    ),
                  );
                }).toList(),
              ),
            ),
          const Divider(height: 1, color: Colors.grey),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      hintText: "Type your message...",
                      hintStyle: const TextStyle(color: Colors.black54),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      prefixIcon: IconButton(
                        icon: Icon(Icons.mic, color: isListening ? Colors.red : Colors.grey),
                        onPressed: () {
                          if (isListening) stopListening();
                          else startListening();
                        },
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.emoji_emotions_outlined),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.send, color: Colors.teal),
                            onPressed: sendMessage,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  Message({required this.text, required this.isUser, required this.timestamp});
}

class MessageWidget extends StatelessWidget {
  final Message message;
  const MessageWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.timestamp);
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                backgroundImage: AssetImage('assets/bot_avatar.png'),
                radius: 16,
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isUser ? Colors.white : const Color(0xFFE6F2FF),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isUser ? const Color(0xFF222222) : const Color(0xFF183C65),
                      fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(time, style: const TextStyle(fontSize: 10, color: Colors.black38)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



//just added this to test the annimated chat bubble
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  _TypingIndicatorState createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dotOne;
  late Animation<double> _dotTwo;
  late Animation<double> _dotThree;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _dotOne = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );
    _dotTwo = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.easeIn)),
    );
    _dotThree = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeIn)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _dotOne,
          child: const Text('.', style: TextStyle(fontSize: 30)),
        ),
        const SizedBox(width: 4),
        FadeTransition(
          opacity: _dotTwo,
          child: const Text('.', style: TextStyle(fontSize: 30)),
        ),
        const SizedBox(width: 4),
        FadeTransition(
          opacity: _dotThree,
          child: const Text('.', style: TextStyle(fontSize: 30)),
        ),
      ],
    );
  }
}