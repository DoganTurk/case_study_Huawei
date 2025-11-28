import threading
import requests
import time
import sys
import random

# --- CONFIGURATION ---
URL = "http://localhost:8000/predict"
PHASES = [
    {"name": "Light Load (Morning)", "users": 2, "duration": 30},
    {"name": "🍔 Mid Load (Lunch)",    "users": 15, "duration": 45},
    {"name": "Heavy Load (Crash)",  "users": 60, "duration": 60},
    {"name": "Cooldown",            "users": 0,  "duration": 20}
]

# Shared flags
keep_running = True
phase_running = False

def user_behavior():
    """Simulates one user sending requests continuously."""
    while phase_running and keep_running:
        try:
            # Randomize text to prevent caching
            payload = {"text": f"load test data {random.randint(1, 1000)}"}
            resp = requests.post(URL, json=payload, timeout=2)
            
            # Visual feedback: Dot = Good, x = Error
            if resp.status_code == 200:
                sys.stdout.write(".")
            else:
                sys.stdout.write("x")
            sys.stdout.flush()
            
            # Sleep slightly to be realistic (0.1s - 0.5s)
            time.sleep(random.uniform(0.1, 0.5))
            
        except:
            sys.stdout.write("!")
            sys.stdout.flush()

def run_phase(phase):
    """Orchestrates a specific load phase."""
    global phase_running
    print(f"\n\n--- [ {phase['name']} ] ---")
    print(f"   👥 Users:    {phase['users']}")
    print(f"   ⏱️ Duration: {phase['duration']}s")
    
    phase_running = True
    threads = []
    
    # Spawn the users
    for _ in range(phase['users']):
        t = threading.Thread(target=user_behavior)
        t.daemon = True # Kills thread if main program exits
        t.start()
        threads.append(t)
        
    # Let them run for the duration
    start_time = time.time()
    while time.time() - start_time < phase['duration']:
        if not keep_running: break
        time.sleep(1)
        
    # Stop this phase
    phase_running = False
    for t in threads:
        t.join(timeout=1)

def main():
    global keep_running
    print("Starting Automatic Scenario Tester")
    print("   Press Ctrl+C to Stop\n")
    
    try:
        while keep_running:
            for phase in PHASES:
                if not keep_running: break
                run_phase(phase)
    except KeyboardInterrupt:
        print("\n\nStopping test...")
        keep_running = False

if __name__ == "__main__":
    main()