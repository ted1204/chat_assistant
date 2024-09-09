import 'dart:async';
import 'dart:convert';
import 'package:final_project/model/chat_message.dart';
// import 'package:final_project/services/memes.dart';
import 'package:http/http.dart' as http;

class ChatService {
  static const String _apiKey =
      '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'; // FIXME: Replace with your API key
  // Assuming you have created an assistant and a thread beforehand and have their IDs
  static const _assistantId = 'asst_vsCxr1Fx4wlEotDtgHmBLUD7'; // friend
  static const String _threadId =
      'thread_7Mt0Eqp97ZXf08O8GLGU8sDk'; // FIXME: Replace with your thread ID
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _messagesUrl = '$_baseUrl/threads/$_threadId/messages';
  static const String _runsUrl = '$_baseUrl/threads/$_threadId/runs';

  // static const String _url = 'https://api.openai.com/v1/images/generations';
  // final _memsService = MemesService();

  Future<Message> fetchPromptResponse(Message prompt) async {

    // For response
    // 1. Post prompt to the thread
    var content = '';
    if (prompt.picture) {
      if (prompt.keywords == ''){
        content = 'my ${prompt.category.name} is chatting with me , he/she sends me "${prompt.text}", help me reply with the appropriate answer and the url of a appropriate meme in this array:["https://memeprod.sgp1.digitaloceanspaces.com/user-wtf/1718956905380.jpg", "https://memeprod.sgp1.digitaloceanspaces.com/user-wtf/1718956704985.jpg", "https://memeprod.sgp1.digitaloceanspaces.com/user-wtf/1718956260814.jpg"] in json format, like:{"reply":"xxx","meme_url":"xxx"}.';
      } else {
        content = 'my ${prompt.category.name} is chatting with me , he/she sends me "${prompt.text}",I want to reply him "${prompt.keywords}", help me reply with the appropriate answer and the url of a appropriate meme in this array:["https://memeprod.sgp1.digitaloceanspaces.com/user-wtf/1718956905380.jpg", "https://memeprod.sgp1.digitaloceanspaces.com/user-wtf/1718956704985.jpg", "https://memeprod.sgp1.digitaloceanspaces.com/user-wtf/1718956260814.jpg"] in json format, like:{"reply":"xxx","meme_url":"xxx"}.';
      }
    }
    else {
      if (prompt.keywords == ''){
        content = 'my ${prompt.category.name} is chatting with me , he/she sends me "${prompt.text}", help me reply with the appropriate answer in json format, like:{"reply":"xxx"}.';
      } else {
        content = 'my ${prompt.category.name} is chatting with me , he/she sends me "${prompt.text}",I want to reply him "${prompt.keywords}", help me reply with the appropriate answer in json format, like:{"reply":"xxx"}.';
      }
    }
    var response = await sendPromptGetResponse(content);
    Map<String, dynamic> jsonMap = json.decode(response);
    String responseText = jsonMap['reply'];
    String responseUrl = prompt.picture ? jsonMap['meme_url'] : '';

    print(responseUrl);
    // if (responseText.contains('「') || responseText.contains('」')) {
    //   responseText = await sendPromptGetResponse('Please give me the content in quotation marks, without the quotation marks', 4);
    // }

    // if (responseText[0] == '"' || responseText[0] == "'") {
    //   responseText = responseText.substring(1);
    // }
    // int length = responseText.length;
    // if (responseText[length - 1] == '"' || responseText[length - 1] == "'") {
    //   responseText = responseText.substring(0,length - 1);
    // }  
    // // For image response
    // if (prompt.picture) {
    //   // 1. Send the prompt to the DALL-E API to generate an image
    //   var promptResponseImage = await http.post(
    //     Uri.parse(_url),
    //     headers: {
    //       'Content-Type': 'application/json; charset=utf-8',
    //       'Authorization': 'Bearer $_apiKey',
    //     },
    //     body: jsonEncode({
    //       'prompt': "a scenario about the message: ${prompt.text}",
    //       'n': 1,
    //       'size': '256x256', // You can adjust the image size as needed
    //     }),
    //   );
    
    //   if (promptResponseImage.statusCode != 200) {
    //     throw Exception('Failed to generate image: ${promptResponseImage.statusCode}');
    //   }

    //   // 2. Update local messages list with the assistant's response
    //   var data = json.decode(utf8.decode(promptResponseImage.bodyBytes));
    //   responseUrl = data['data'][0]['url'];
    // }

    Message responseMessage = Message (
      user: 'GPT',
      text: responseText,
      userID: prompt.userID,
      category: prompt.category,
      keywords: prompt.keywords,
      picture: prompt.picture,
      memesUrl : responseUrl,
    );
    return responseMessage;
  }
  
  Future<String> sendPromptGetResponse(String content) async {
    var promptResponseText = await http.post(
      Uri.parse(_messagesUrl),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $_apiKey',
        'OpenAI-Beta': 'assistants=v1',
      },
      body: jsonEncode({
        'role': 'user',
        'content': content,
      }),
    );
    // Check if the prompt was successfully added
    if (promptResponseText.statusCode != 200) {
      throw Exception('Failed to add prompt: ${promptResponseText.statusCode}');
    }

    // 2. Creating a run to generate a response
    var runResponse = await http.post(
      Uri.parse(_runsUrl),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $_apiKey',
        'OpenAI-Beta': 'assistants=v1',
      },
      body: jsonEncode({
        'assistant_id': _assistantId,
        // Additional instructions can be passed here if needed
      }),
    );
    // Check if run was successfully created
    if (runResponse.statusCode != 200) {
      throw Exception('Failed to create a run: ${runResponse.statusCode}');
    }

    // 3. Wait for the run to complete
    var runData = json.decode(runResponse.body);
    var runId = runData['id'];
    String runStatusUrl = '$_baseUrl/threads/$_threadId/runs/$runId';
    while (true) {
      // Wait for a short period before checking again
      await Future.delayed(Duration(seconds: 2));

      var runStatusResponse = await http.get(
        Uri.parse(runStatusUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json; charset=utf-8',
          'OpenAI-Beta': 'assistants=v1',
        },
      );
      if (runStatusResponse.statusCode != 200) {
        throw Exception(
            'Failed to query run status: ${runStatusResponse.statusCode}');
      }
      var runStatusData = json.decode(runStatusResponse.body);
      var runStatus = runStatusData['status'];
      if (runStatus == 'cancelled' ||
          runStatus == 'failed' ||
          runStatus == 'expired') {
        throw Exception('Run failed: ${runStatusData['status']}');
      }
      // Indicate that Function Calling is used (see: https://platform.openai.com/docs/assistants/tools/function-calling)
      if (runStatus == 'requires_action') {
      }
      if (runStatus == 'completed') {
        break;
      }
    }

    var response = await http.get(
      Uri.parse(_messagesUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'OpenAI-Beta': 'assistants=v1',
      },
    );

    // Check if messages were successfully fetched
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch messages: ${response.statusCode}');
    }

    var responseData = json.decode(utf8.decode(response.bodyBytes));
    var responseText = responseData['data'][0]['content'][0]['text']['value'].toString();
    return responseText;
  }
}
