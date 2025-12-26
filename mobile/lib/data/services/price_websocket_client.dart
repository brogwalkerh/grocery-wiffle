import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket client for real-time price updates from the backend.
/// 
/// Connects to the backend and subscribes to price updates for products
/// the user is interested in.
class PriceWebSocketClient {
  final String baseUrl;
  final String userId;
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  
  final _priceUpdatesController = StreamController<PriceUpdate>.broadcast();
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  
  bool _isConnected = false;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  
  /// Stream of price updates
  Stream<PriceUpdate> get priceUpdates => _priceUpdatesController.stream;
  
  /// Stream of connection state changes
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;
  
  /// Whether currently connected
  bool get isConnected => _isConnected;

  PriceWebSocketClient({
    required this.baseUrl,
    required this.userId,
  });

  /// Connect to the WebSocket server.
  Future<void> connect() async {
    if (_isConnected) return;
    
    try {
      final wsUrl = baseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
      
      final uri = Uri.parse('$wsUrl/ws/prices/$userId');
      _channel = WebSocketChannel.connect(uri);
      
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
      
      _isConnected = true;
      _connectionStateController.add(ConnectionState.connected);
      
      // Start ping timer to keep connection alive
      _startPingTimer();
      
    } catch (e) {
      _connectionStateController.add(ConnectionState.error);
      _scheduleReconnect();
    }
  }

  /// Disconnect from the WebSocket server.
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    await _channel?.sink.close();
    
    _isConnected = false;
    _connectionStateController.add(ConnectionState.disconnected);
  }

  /// Subscribe to price updates for specific products.
  void subscribeToProducts(List<String> products) {
    _sendMessage({
      'action': 'subscribe',
      'products': products,
    });
  }

  /// Unsubscribe from price updates for specific products.
  void unsubscribeFromProducts(List<String> products) {
    _sendMessage({
      'action': 'unsubscribe',
      'products': products,
    });
  }

  /// Get current subscriptions.
  void getSubscriptions() {
    _sendMessage({'action': 'get_subscriptions'});
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;
      
      switch (type) {
        case 'connected':
          _connectionStateController.add(ConnectionState.connected);
          break;
          
        case 'price_update':
          final update = PriceUpdate.fromJson(message);
          _priceUpdatesController.add(update);
          break;
          
        case 'subscribed':
          // Handle subscription confirmation
          break;
          
        case 'pong':
          // Ping response received
          break;
          
        default:
          print('Unknown WebSocket message type: $type');
      }
    } catch (e) {
      print('Error handling WebSocket message: $e');
    }
  }

  void _handleError(dynamic error) {
    print('WebSocket error: $error');
    _connectionStateController.add(ConnectionState.error);
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    _connectionStateController.add(ConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendMessage({'action': 'ping'});
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  void dispose() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _priceUpdatesController.close();
    _connectionStateController.close();
  }
}


enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}


class PriceUpdate {
  final String product;
  final String productName;
  final double price;
  final String storeChain;
  final String timestamp;

  PriceUpdate({
    required this.product,
    required this.productName,
    required this.price,
    required this.storeChain,
    required this.timestamp,
  });

  factory PriceUpdate.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return PriceUpdate(
      product: json['product'] as String,
      productName: data['product_name'] as String,
      price: (data['price'] as num).toDouble(),
      storeChain: data['store_chain'] as String,
      timestamp: data['timestamp'] as String,
    );
  }
}
