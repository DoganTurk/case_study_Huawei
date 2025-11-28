import time
import random
from fastapi import FastAPI, Response
from pydantic import BaseModel
from prometheus_client import start_http_server, Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

app = FastAPI()

INFERENCE_LATENCY = Histogram('inference_latency_seconds', 'Time spent processing inference')
PREDICTION_COUNT = Counter('prediction_count_total', 'Total number of predictions requested')
CONFIDENCE_SCORE = Gauge('model_confidence_score', 'Confidence score of the last prediction')

class SentimentRequest(BaseModel):
    text: str

@app.get('/health')
def health_check():
    return {'status': 'healthy'}

@app.post('/predict')
def predict(request: SentimentRequest):
    start_time = time.time()
    time.sleep(random.uniform(0.1, 0.6)) 
    sentiment_score = random.uniform(0.0, 1.0)
    confidence = random.uniform(0.7, 0.99)
    
    INFERENCE_LATENCY.observe(time.time() - start_time)
    PREDICTION_COUNT.inc()
    CONFIDENCE_SCORE.set(confidence)
    
    return {'sentiment': sentiment_score, 'confidence': confidence}

@app.get('/metrics')
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)
