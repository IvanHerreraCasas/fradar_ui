// lib/data/services/sse_service.dart
import 'dart:async';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart'; // Import the correct package

class SseService {
  final String _apiBaseUrl; // e.g., http://localhost:8000/api/v1
  StreamSubscription? _sseSubscription;
  // flutter_client_sse manages the stream internally, we subscribe to it
  final StreamController<SSEModel> _eventStreamController = StreamController<SSEModel>.broadcast();


  // Constructor takes the full base API URL (including /api/v1)
  SseService({required String apiBaseUrl}) : _apiBaseUrl = apiBaseUrl {
      _connect(); // Start connection attempt immediately or on first listen
  }

  /// Provides a stream of SSEModel events received from the server.
  Stream<SSEModel> get events => _eventStreamController.stream;


  void _connect() {
     final sseUrl = '$_apiBaseUrl/plots/stream/updates';
     print('SSE: Subscribing to $sseUrl');
     _sseSubscription?.cancel();

     _sseSubscription = SSEClient.subscribeToSSE(
       // Specify the HTTP method - typically GET for SSE
       method: SSERequestType.GET, // ***** ADD THIS LINE *****
       url: sseUrl,
       header: {
         "Accept": "text/event-stream",
         "Cache-Control": "no-cache",
       },
       // body: null, // Only needed for POST/PUT etc.
     ).listen(
       (event) {
         print('SSE: Received event: ID=${event.id}, Event=${event.event}, Data=${event.data}');
          _eventStreamController.add(event);
       },
       onError: (error) {
         print('SSE: Error received: $error');
         _eventStreamController.addError(error);
         _reconnectAfterDelay();
       },
       onDone: () {
          print('SSE: Stream closed by package/server.');
          _reconnectAfterDelay();
       },
       cancelOnError: false,
     );
  }
  void _reconnectAfterDelay() {
     print('SSE: Attempting reconnect in 5 seconds...');
     // Unsubscribe before attempting reconnect to avoid multiple connections
     _sseSubscription?.cancel();
     _sseSubscription = null;
     Future.delayed(const Duration(seconds: 5), () {
        if (!_eventStreamController.isClosed) {
           _connect(); // Attempt connection again
        }
     });
  }


  // Call this when the service is no longer needed
  void dispose() {
    print('SSE: Disposing service and unsubscribing.');
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _eventStreamController.close();
    // SSEClient.unsubscribeFromSSE(); // Check if package requires a global unsubscribe
  }
}