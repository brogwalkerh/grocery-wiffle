"""
Background Scheduler for Price Crawling.

Schedules and manages periodic price crawl jobs.
"""

import asyncio
from datetime import datetime, timedelta
from typing import Callable, Optional
from dataclasses import dataclass, field
import logging

logger = logging.getLogger(__name__)


@dataclass
class CrawlJob:
    """A scheduled crawl job."""
    job_id: str
    product_query: str
    interval_hours: float
    last_run: Optional[datetime] = None
    next_run: Optional[datetime] = None
    enabled: bool = True
    priority: int = 1  # 1 = high, 5 = low


@dataclass 
class CrawlQueue:
    """Queue of products to crawl."""
    items: list[str] = field(default_factory=list)
    
    def add(self, query: str):
        if query not in self.items:
            self.items.append(query)
    
    def pop(self) -> Optional[str]:
        if self.items:
            return self.items.pop(0)
        return None
    
    def __len__(self) -> int:
        return len(self.items)


class PriceCrawlScheduler:
    """
    Manages scheduled price crawling tasks.
    
    Features:
    - Periodic crawling of popular products
    - On-demand crawling for user requests
    - Priority queue for crawl requests
    - Rate limiting and backoff
    """
    
    # Common grocery items to crawl regularly
    COMMON_PRODUCTS = [
        'milk', 'bread', 'eggs', 'butter', 'cheese',
        'chicken breast', 'ground beef', 'bacon',
        'apples', 'bananas', 'oranges', 'lettuce', 'tomatoes',
        'rice', 'pasta', 'flour', 'sugar', 'coffee',
        'orange juice', 'cereal', 'yogurt',
        'paper towels', 'toilet paper',
    ]
    
    def __init__(self, crawler, storage_service):
        self.crawler = crawler
        self.storage = storage_service
        self.jobs: dict[str, CrawlJob] = {}
        self.queue = CrawlQueue()
        self._running = False
        self._task: Optional[asyncio.Task] = None
        
        # Stats
        self.total_crawls = 0
        self.successful_crawls = 0
        self.failed_crawls = 0
        self.last_crawl_time: Optional[datetime] = None
    
    def schedule_common_products(self, interval_hours: float = 6.0):
        """Schedule crawling for common grocery products."""
        for product in self.COMMON_PRODUCTS:
            job_id = f"common_{product.replace(' ', '_')}"
            self.jobs[job_id] = CrawlJob(
                job_id=job_id,
                product_query=product,
                interval_hours=interval_hours,
                next_run=datetime.now(),
                priority=3,  # Medium priority for common items
            )
        
        logger.info(f"Scheduled {len(self.COMMON_PRODUCTS)} common products for crawling")
    
    def schedule_user_product(self, product_query: str, priority: int = 1):
        """Schedule an on-demand crawl for a user-requested product."""
        job_id = f"user_{product_query.replace(' ', '_')}_{datetime.now().timestamp()}"
        self.jobs[job_id] = CrawlJob(
            job_id=job_id,
            product_query=product_query,
            interval_hours=0,  # One-time job
            next_run=datetime.now(),
            priority=priority,
        )
        
        # Also add to immediate queue
        self.queue.add(product_query)
        
        logger.info(f"Scheduled user product for crawling: {product_query}")
    
    def add_to_queue(self, product_query: str):
        """Add a product to the immediate crawl queue."""
        self.queue.add(product_query)
    
    async def start(self):
        """Start the scheduler background task."""
        if self._running:
            return
        
        self._running = True
        self._task = asyncio.create_task(self._run_scheduler())
        logger.info("Price crawl scheduler started")
    
    async def stop(self):
        """Stop the scheduler."""
        self._running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        logger.info("Price crawl scheduler stopped")
    
    async def _run_scheduler(self):
        """Main scheduler loop."""
        while self._running:
            try:
                # First, process immediate queue
                while len(self.queue) > 0:
                    query = self.queue.pop()
                    if query:
                        await self._crawl_product(query)
                
                # Then check scheduled jobs
                now = datetime.now()
                due_jobs = [
                    job for job in self.jobs.values()
                    if job.enabled and job.next_run and job.next_run <= now
                ]
                
                # Sort by priority (lower = higher priority)
                due_jobs.sort(key=lambda j: j.priority)
                
                for job in due_jobs[:5]:  # Process up to 5 jobs per cycle
                    await self._crawl_product(job.product_query)
                    job.last_run = now
                    
                    if job.interval_hours > 0:
                        # Reschedule recurring job
                        job.next_run = now + timedelta(hours=job.interval_hours)
                    else:
                        # One-time job, disable it
                        job.enabled = False
                
                # Sleep before next check
                await asyncio.sleep(10)  # Check every 10 seconds
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Scheduler error: {e}")
                await asyncio.sleep(30)  # Wait longer on error
    
    async def _crawl_product(self, query: str):
        """Crawl a single product and store results."""
        self.total_crawls += 1
        self.last_crawl_time = datetime.now()
        
        try:
            logger.info(f"Crawling prices for: {query}")
            
            prices = await self.crawler.crawl_all_stores(query)
            
            if prices:
                stored = await self.storage.store_prices(prices)
                self.successful_crawls += 1
                logger.info(f"Stored {stored} prices for '{query}'")
            else:
                logger.warning(f"No prices found for '{query}'")
                
        except Exception as e:
            self.failed_crawls += 1
            logger.error(f"Failed to crawl '{query}': {e}")
    
    def get_stats(self) -> dict:
        """Get scheduler statistics."""
        return {
            'total_crawls': self.total_crawls,
            'successful_crawls': self.successful_crawls,
            'failed_crawls': self.failed_crawls,
            'success_rate': (self.successful_crawls / self.total_crawls * 100) if self.total_crawls > 0 else 0,
            'queue_length': len(self.queue),
            'scheduled_jobs': len([j for j in self.jobs.values() if j.enabled]),
            'last_crawl': self.last_crawl_time.isoformat() if self.last_crawl_time else None,
        }


# Global scheduler instance
_scheduler: Optional[PriceCrawlScheduler] = None


def get_scheduler() -> Optional[PriceCrawlScheduler]:
    """Get the global scheduler instance."""
    return _scheduler


async def init_scheduler(crawler, storage_service) -> PriceCrawlScheduler:
    """Initialize and start the global scheduler."""
    global _scheduler
    
    _scheduler = PriceCrawlScheduler(crawler, storage_service)
    _scheduler.schedule_common_products()
    await _scheduler.start()
    
    return _scheduler


async def shutdown_scheduler():
    """Shutdown the global scheduler."""
    global _scheduler
    
    if _scheduler:
        await _scheduler.stop()
        _scheduler = None
