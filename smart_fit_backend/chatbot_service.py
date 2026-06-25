import os
import logging
from typing import Optional, List, Dict, Any

# Attempt to import Gemini SDK safely
try:
    import google.generativeai as genai
    GENAI_AVAILABLE = True
except ImportError:
    GENAI_AVAILABLE = False

logger = logging.getLogger("smart_fit_backend.chatbot")

class ChatbotService:
    def __init__(self):
        self.api_key = os.environ.get("GEMINI_API_KEY")
        self.mode = "mock"
        self.model = None

        if self.api_key and GENAI_AVAILABLE:
            try:
                genai.configure(api_key=self.api_key)
                self.mode = "gemini"
                logger.info("ChatbotService initialized in GEMINI mode.")
            except Exception as e:
                logger.error(f"Failed to initialize Gemini, falling back to mock mode: {e}")
                self.mode = "mock"
        else:
            logger.info("ChatbotService initialized in MOCK mode (No API key or SDK missing).")

    def generate_response(self, system_prompt: str, user_message: str, history: Optional[List[Dict[str, Any]]] = None) -> dict:
        """
        Generates a chat response using Gemini if available, otherwise returns a mock response.
        history: Expected to be a list of dicts like [{"role": "user", "parts": ["hello"]}, ...]
        """
        if self.mode == "mock":
            return {
                "response": "Chatbot is running in test mode. AI integration is active but not connected to Gemini yet.",
                "mode": "mock",
                "source": "chatbot_service"
            }

        try:
            model_with_sys = genai.GenerativeModel(
                model_name='gemini-2.5-flash',
                system_instruction=system_prompt
            )

            formatted_history = []
            if history:
                for msg in history:
                    role = msg.get("role", "user")
                    parts = msg.get("parts", [])
                    if role not in ["user", "model"]:
                        role = "user" if role != "assistant" else "model"
                    
                    formatted_history.append({"role": role, "parts": parts})

            chat = model_with_sys.start_chat(history=formatted_history)
            response = chat.send_message(user_message)

            return {
                "response": response.text if response.text else "Sorry, I could not generate a response.",
                "mode": "gemini",
                "source": "chatbot_service"
            }
        except Exception as e:
            logger.error(f"Gemini API call failed: {e}")
            error_str = str(e).lower()
            if "403" in error_str or "denied access" in error_str:
                resp_msg = "AI Coach is unavailable: Your Google Cloud project was denied access (Error 403). Please verify billing and API restrictions."
            elif "401" in error_str or "api key not valid" in error_str:
                resp_msg = "AI Coach is unavailable: The provided Gemini API Key is invalid."
            elif "429" in error_str or "quota" in error_str or "rate limit" in error_str:
                resp_msg = "AI Coach is unavailable: The Gemini API Key has exceeded its free tier quota (Error 429). Please verify billing details or wait for the quota to reset."
            else:
                resp_msg = "Chatbot is running in test mode. AI integration is active but Gemini threw an error."
            return {
                "response": resp_msg,
                "mode": "mock",
                "source": "chatbot_service"
            }

# Singleton instance
chatbot_service = ChatbotService()
