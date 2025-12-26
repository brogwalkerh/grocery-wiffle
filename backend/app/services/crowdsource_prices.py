"""Crowdsourced price correction service.

This module handles user-submitted price corrections, similar to GasBuddy.
Prices are stored locally and can be used to improve accuracy.
"""

import json
import os
from datetime import datetime, timedelta
from typing import Optional
from pathlib import Path
from pydantic import BaseModel


class PriceCorrection(BaseModel):
    """A user-submitted price correction."""
    item_name: str
    store_name: str
    store_chain: str
    store_id: Optional[int] = None
    old_price: float
    new_price: float
    product_size: Optional[str] = None
    submitted_at: str
    is_verified: bool = False
    upvotes: int = 0
    downvotes: int = 0


class CrowdsourcePriceService:
    """Service for managing crowdsourced price corrections."""
    
    def __init__(self, storage_path: Optional[str] = None):
        """Initialize the service with a storage path."""
        if storage_path is None:
            # Store in backend directory
            storage_path = os.path.join(
                os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
                "data",
                "crowdsourced_prices.json"
            )
        self.storage_path = Path(storage_path)
        self.storage_path.parent.mkdir(parents=True, exist_ok=True)
        self._corrections: list[dict] = []
        self._load()
    
    def _load(self):
        """Load corrections from storage."""
        if self.storage_path.exists():
            try:
                with open(self.storage_path, 'r') as f:
                    self._corrections = json.load(f)
            except (json.JSONDecodeError, IOError):
                self._corrections = []
        else:
            self._corrections = []
    
    def _save(self):
        """Save corrections to storage."""
        with open(self.storage_path, 'w') as f:
            json.dump(self._corrections, f, indent=2)
    
    def submit_correction(
        self,
        item_name: str,
        store_name: str,
        store_chain: str,
        old_price: float,
        new_price: float,
        product_size: Optional[str] = None,
        store_id: Optional[int] = None,
    ) -> PriceCorrection:
        """Submit a new price correction."""
        correction = PriceCorrection(
            item_name=item_name.lower().strip(),
            store_name=store_name,
            store_chain=store_chain,
            store_id=store_id,
            old_price=old_price,
            new_price=new_price,
            product_size=product_size,
            submitted_at=datetime.utcnow().isoformat(),
            is_verified=False,
            upvotes=1,  # Auto-upvote by submitter
            downvotes=0,
        )
        
        # Check for existing correction for same item/store
        existing_idx = None
        for idx, c in enumerate(self._corrections):
            if (c['item_name'] == correction.item_name and 
                c['store_name'] == correction.store_name):
                existing_idx = idx
                break
        
        if existing_idx is not None:
            # Update existing correction if newer
            self._corrections[existing_idx] = correction.model_dump()
        else:
            self._corrections.append(correction.model_dump())
        
        self._save()
        return correction
    
    def vote(self, item_name: str, store_name: str, is_upvote: bool) -> Optional[dict]:
        """Vote on a price correction."""
        item_name = item_name.lower().strip()
        
        for correction in self._corrections:
            if (correction['item_name'] == item_name and 
                correction['store_name'] == store_name):
                if is_upvote:
                    correction['upvotes'] = correction.get('upvotes', 0) + 1
                else:
                    correction['downvotes'] = correction.get('downvotes', 0) + 1
                
                # Auto-verify if enough upvotes
                if correction['upvotes'] >= 3 and correction['downvotes'] < correction['upvotes']:
                    correction['is_verified'] = True
                
                self._save()
                return correction
        
        return None
    
    def get_correction(
        self,
        item_name: str,
        store_name: str,
        max_age_hours: int = 168  # 1 week default
    ) -> Optional[dict]:
        """Get a price correction if available and recent enough."""
        item_name = item_name.lower().strip()
        cutoff = datetime.utcnow() - timedelta(hours=max_age_hours)
        
        for correction in self._corrections:
            if (correction['item_name'] == item_name and 
                correction['store_name'] == store_name):
                submitted = datetime.fromisoformat(correction['submitted_at'])
                if submitted >= cutoff:
                    # Return if has positive score
                    score = correction.get('upvotes', 0) - correction.get('downvotes', 0)
                    if score >= 0:
                        return correction
        
        return None
    
    def get_corrections_for_store(
        self,
        store_name: str,
        max_age_hours: int = 168
    ) -> list[dict]:
        """Get all corrections for a specific store."""
        cutoff = datetime.utcnow() - timedelta(hours=max_age_hours)
        results = []
        
        for correction in self._corrections:
            if correction['store_name'] == store_name:
                submitted = datetime.fromisoformat(correction['submitted_at'])
                if submitted >= cutoff:
                    score = correction.get('upvotes', 0) - correction.get('downvotes', 0)
                    if score >= 0:
                        results.append(correction)
        
        return results
    
    def get_all_corrections(
        self,
        max_age_hours: int = 168,
        verified_only: bool = False
    ) -> list[dict]:
        """Get all recent corrections."""
        cutoff = datetime.utcnow() - timedelta(hours=max_age_hours)
        results = []
        
        for correction in self._corrections:
            submitted = datetime.fromisoformat(correction['submitted_at'])
            if submitted >= cutoff:
                if verified_only and not correction.get('is_verified', False):
                    continue
                score = correction.get('upvotes', 0) - correction.get('downvotes', 0)
                if score >= 0:
                    results.append(correction)
        
        return sorted(results, key=lambda x: x['submitted_at'], reverse=True)
    
    def get_stats(self) -> dict:
        """Get statistics about crowdsourced prices."""
        total = len(self._corrections)
        verified = sum(1 for c in self._corrections if c.get('is_verified', False))
        recent = len(self.get_all_corrections(max_age_hours=24))
        
        return {
            "total_corrections": total,
            "verified_corrections": verified,
            "corrections_last_24h": recent,
            "top_contributors": 0,  # Would need user tracking
        }


# Singleton instance
_service: Optional[CrowdsourcePriceService] = None


def get_crowdsource_service() -> CrowdsourcePriceService:
    """Get or create the crowdsource price service."""
    global _service
    if _service is None:
        _service = CrowdsourcePriceService()
    return _service
