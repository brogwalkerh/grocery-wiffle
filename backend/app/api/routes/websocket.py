"""WebSocket endpoints for real-time price updates."""

import asyncio
import json
from datetime import datetime
from typing import Optional
from dataclasses import dataclass, field

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel


router = APIRouter()


@dataclass
class PriceUpdate:
    """A price update to broadcast."""
    product_name: str
    price: float
    store_chain: str
    timestamp: str = field(default_factory=lambda: datetime.now().isoformat())


class ConnectionManager:
    """Manages WebSocket connections for price updates."""
    
    def __init__(self):
        # Active connections by user_id
        self.active_connections: dict[str, WebSocket] = {}
        # Product subscriptions: product_query -> set of user_ids
        self.subscriptions: dict[str, set[str]] = {}
    
    async def connect(self, websocket: WebSocket, user_id: str):
        """Accept a new WebSocket connection."""
        await websocket.accept()
        self.active_connections[user_id] = websocket
    
    def disconnect(self, user_id: str):
        """Remove a WebSocket connection."""
        if user_id in self.active_connections:
            del self.active_connections[user_id]
        
        # Remove from all subscriptions
        for product, subscribers in self.subscriptions.items():
            subscribers.discard(user_id)
    
    def subscribe(self, user_id: str, product_query: str):
        """Subscribe a user to price updates for a product."""
        if product_query not in self.subscriptions:
            self.subscriptions[product_query] = set()
        self.subscriptions[product_query].add(user_id)
    
    def unsubscribe(self, user_id: str, product_query: str):
        """Unsubscribe a user from a product."""
        if product_query in self.subscriptions:
            self.subscriptions[product_query].discard(user_id)
    
    async def send_personal_message(self, message: dict, user_id: str):
        """Send a message to a specific user."""
        websocket = self.active_connections.get(user_id)
        if websocket:
            try:
                await websocket.send_json(message)
            except Exception:
                self.disconnect(user_id)
    
    async def broadcast_price_update(self, product_query: str, update: PriceUpdate):
        """Broadcast a price update to all subscribers."""
        subscribers = self.subscriptions.get(product_query.lower(), set())
        
        message = {
            'type': 'price_update',
            'product': product_query,
            'data': {
                'product_name': update.product_name,
                'price': update.price,
                'store_chain': update.store_chain,
                'timestamp': update.timestamp,
            }
        }
        
        for user_id in subscribers:
            await self.send_personal_message(message, user_id)
    
    async def broadcast_to_all(self, message: dict):
        """Broadcast a message to all connected users."""
        disconnected = []
        
        for user_id, websocket in self.active_connections.items():
            try:
                await websocket.send_json(message)
            except Exception:
                disconnected.append(user_id)
        
        for user_id in disconnected:
            self.disconnect(user_id)


# Global connection manager
manager = ConnectionManager()


def get_connection_manager() -> ConnectionManager:
    """Get the global connection manager."""
    return manager


@router.websocket("/ws/prices/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    """
    WebSocket endpoint for real-time price updates.
    
    Messages from client:
    - {"action": "subscribe", "products": ["milk", "eggs"]}
    - {"action": "unsubscribe", "products": ["milk"]}
    - {"action": "ping"}
    
    Messages to client:
    - {"type": "connected", "user_id": "..."}
    - {"type": "price_update", "product": "milk", "data": {...}}
    - {"type": "subscribed", "products": [...]}
    - {"type": "pong"}
    """
    await manager.connect(websocket, user_id)
    
    try:
        # Send connection confirmation
        await websocket.send_json({
            'type': 'connected',
            'user_id': user_id,
            'timestamp': datetime.now().isoformat(),
        })
        
        while True:
            # Wait for messages from client
            data = await websocket.receive_json()
            action = data.get('action')
            
            if action == 'subscribe':
                products = data.get('products', [])
                for product in products:
                    manager.subscribe(user_id, product.lower())
                
                await websocket.send_json({
                    'type': 'subscribed',
                    'products': products,
                })
            
            elif action == 'unsubscribe':
                products = data.get('products', [])
                for product in products:
                    manager.unsubscribe(user_id, product.lower())
                
                await websocket.send_json({
                    'type': 'unsubscribed',
                    'products': products,
                })
            
            elif action == 'ping':
                await websocket.send_json({'type': 'pong'})
            
            elif action == 'get_subscriptions':
                # Return current subscriptions
                user_subs = [
                    product for product, users in manager.subscriptions.items()
                    if user_id in users
                ]
                await websocket.send_json({
                    'type': 'subscriptions',
                    'products': user_subs,
                })
                
    except WebSocketDisconnect:
        manager.disconnect(user_id)
    except Exception as e:
        print(f"WebSocket error for {user_id}: {e}")
        manager.disconnect(user_id)


# Helper function to broadcast price updates from the crawler
async def notify_price_update(product_query: str, update: PriceUpdate):
    """Notify all subscribers of a price update."""
    await manager.broadcast_price_update(product_query, update)
