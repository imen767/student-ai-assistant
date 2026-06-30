import logging
import os
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)

from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from flask import Flask, request, jsonify,session,render_template
import uuid
from dotenv import load_dotenv
load_dotenv()
FOUNDRY_ENDPOINT = os.environ.get("FOUNDRY_ENDPOINT", "")
AGENT_NAME = os.environ.get("AGENT_NAME", "")
_foundry_client = None
_openai_client = None

if FOUNDRY_ENDPOINT and AGENT_NAME:
    try:
        _foundry_client = AIProjectClient(endpoint=FOUNDRY_ENDPOINT, 
                                          credential=DefaultAzureCredential())
        _openai_client = _foundry_client.get_openai_client()
    except Exception as e:
        logger.warning("Could not initialize: %s", e)

_conversations: dict[str, str] = {}

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "default_secret_key")
@app.route("/chat", methods=["POST"])
def chat():
    session_id = session.get('session_id')

    # Vérification 1 : session_id existe ?
    if not session_id:
       session_id = str(uuid.uuid4())
       session['session_id'] = session_id

    # Vérification 2 : conversation Foundry existe ?
    if session_id not in _conversations:
        conv = _openai_client.conversations.create()
        _conversations[session_id] = conv.id

    # 1. Reçoit le JSON du navigateur
    data = request.get_json()
    user_text = data.get("message")
    

    # 2. Appelle Foundry (identique au tuto)
    response = _openai_client.responses.create(
        conversation=_conversations.get(session_id),
        input=user_text,
        extra_body={"agent_reference":{"name": AGENT_NAME, "type": "agent_reference"}}
    )

    # 3. Répond au navigateur en JSON
    return jsonify({"reply": response.output_text})
@app.route("/reset", methods=["POST"])
def reset():
    session_id = session.get('session_id')
    if session_id and session_id in _conversations:
        del _conversations[session_id]
        session.clear()  # Clear the session to remove the session_id ici c'est from flask
    return jsonify({"status": "conversation reset"})
@app.route("/")
def index():
    return render_template("index.html")
if __name__ == "__main__":
   port = int(os.environ.get("PORT", 5000))
   app.run(host="0.0.0.0", port=port)