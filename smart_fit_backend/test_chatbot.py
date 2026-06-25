import os
from dotenv import load_dotenv

# Load environment variables from .env
load_dotenv()

from chatbot_service import chatbot_service

if __name__ == "__main__":
    print(f"API Key loaded: {os.environ.get('GEMINI_API_KEY')[:5]}... (length: {len(os.environ.get('GEMINI_API_KEY') or '')})")
    print(f"Chatbot mode: {chatbot_service.mode}")
    
    print("\n--- Sending test message ---")
    response = chatbot_service.generate_response(
        system_prompt="You are a helpful AI fitness coach.",
        user_message="Hello, can you give me a quick fitness tip?",
        history=[]
    )
    
    print(f"\nResponse Mode: {response.get('mode')}")
    print(f"Response Source: {response.get('source')}")
    print(f"Response Text:\n{response.get('response')}")
