
import io
import json
import os
import traceback

from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from google import genai
from PIL import Image
from pydantic import BaseModel

load_dotenv()

API_KEY = os.getenv("GEMINI_API_KEY")
if not API_KEY:
    raise RuntimeError("GEMINI_API_KEY was not found in .env")

client = genai.Client(api_key=API_KEY)
MODEL_NAME = "gemini-3.5-flash"

app = FastAPI(title="Urban Farming AI Backend", version="1.2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# English names and native-script names are both accepted.
LANGUAGE_ALIASES = {
    "english": "English",
    "en": "English",

    "hindi": "Hindi",
    "हिन्दी": "Hindi",
    "हिंदी": "Hindi",
    "hi": "Hindi",

    "gujarati": "Gujarati",
    "ગુજરાતી": "Gujarati",
    "gu": "Gujarati",

    "marathi": "Marathi",
    "मराठी": "Marathi",
    "mr": "Marathi",

    "bengali": "Bengali",
    "বাংলা": "Bengali",
    "bn": "Bengali",

    "tamil": "Tamil",
    "தமிழ்": "Tamil",
    "ta": "Tamil",

    "telugu": "Telugu",
    "తెలుగు": "Telugu",
    "te": "Telugu",

    "kannada": "Kannada",
    "ಕನ್ನಡ": "Kannada",
    "kn": "Kannada",

    "malayalam": "Malayalam",
    "മലയാളം": "Malayalam",
    "ml": "Malayalam",

    "punjabi": "Punjabi",
    "ਪੰਜਾਬੀ": "Punjabi",
    "pa": "Punjabi",

    "odia": "Odia",
    "ଓଡ଼ିଆ": "Odia",
    "oriya": "Odia",
    "or": "Odia",

    "assamese": "Assamese",
    "অসমীয়া": "Assamese",
    "as": "Assamese",
}


def normalize_language(language: str | None) -> str:
    if not language:
        return "English"

    key = language.strip().lower()
    return LANGUAGE_ALIASES.get(key, "English")


def language_instruction(language: str) -> str:
    return f"""
LANGUAGE REQUIREMENTS:
- Write all user-facing explanations and recommendations in {language}.
- Keep all required JSON keys exactly as specified.
- Do not translate or rename JSON keys.
- Keep status and severity values in their specified canonical
  English categories so the app can interpret them.
- Translate the disease explanation, observations, causes,
  treatment, prevention, watering advice, sunlight advice,
  recovery plan, and other explanatory text into {language}.
- Plant names may include scientific names where useful.
- Return valid JSON only, without Markdown fences.
"""


def safe_json(text: str | None) -> dict:
    if not text:
        raise ValueError("The AI returned an empty response.")

    text = text.strip()

    if text.startswith("```"):
        first_newline = text.find("\n")
        if first_newline != -1:
            text = text[first_newline + 1:]

        if text.rstrip().endswith("```"):
            text = text.rstrip()[:-3]

        text = text.strip()

    try:
        result = json.loads(text)
    except json.JSONDecodeError:
        start = text.find("{")
        end = text.rfind("}")

        if start == -1 or end <= start:
            raise ValueError("The AI did not return valid JSON.")

        result = json.loads(text[start:end + 1])

    if not isinstance(result, dict):
        raise ValueError("The AI response must be a JSON object.")

    return result


def normalize_string_list(value):
    if isinstance(value, list):
        return [
            item if isinstance(item, dict) else str(item)
            for item in value
            if item is not None
        ]

    if isinstance(value, str) and value.strip():
        return [value.strip()]

    return []


@app.get("/")
def root():
    return {
        "status": "online",
        "service": "Urban Farming AI",
        "model": MODEL_NAME,
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "ai": "ready",
        "model": MODEL_NAME,
        "languages": [
            "English",
            "Hindi",
            "Gujarati",
            "Marathi",
            "Bengali",
            "Tamil",
            "Telugu",
            "Kannada",
            "Malayalam",
            "Punjabi",
            "Odia",
            "Assamese",
        ],
    }


@app.post("/analyze")
async def analyze_plant(
    file: UploadFile = File(...),
    language: str = Form("English"),
    plantId: str | None = Form(None),
    plantName: str | None = Form(None),
):
    try:
        selected_language = normalize_language(language)
        image_bytes = await file.read()

        if not image_bytes:
            raise HTTPException(
                status_code=400,
                detail="Empty image.",
            )

        try:
            image = Image.open(io.BytesIO(image_bytes))

            if image.format not in {"JPEG", "PNG", "WEBP"}:
                raise HTTPException(
                    status_code=400,
                    detail="Please upload a JPG, PNG, or WEBP image.",
                )

            image = image.convert("RGB")

        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(
                status_code=400,
                detail="The uploaded file is not a valid JPG, PNG, or WEBP image.",
            ) from exc

        plant_context = ""
        if plantName and plantName.strip():
            plant_context += (
                f"\nUser-provided plant name: {plantName.strip()}"
            )

        if plantId and plantId.strip():
            plant_context += (
                "\nA plant ID is associated with this scan. "
                "Do not invent details based on the ID."
            )

        prompt = f"""
You are an AI urban farming and plant-care assistant.

Analyze the uploaded plant image carefully.
Base conclusions on visible evidence and do not claim certainty
when the image does not support a reliable diagnosis.

{plant_context}

{language_instruction(selected_language)}

Return ONLY valid JSON using this exact structure:

{{
  "plant": "string",
  "disease": "string",
  "status": "Healthy / Mild / Moderate / Severe / Unclear",
  "confidence": 0,
  "severity": "None / Mild / Moderate / Severe",
  "observations": ["string"],
  "possibleCauses": ["string"],
  "treatment": ["string"],
  "prevention": ["string"],
  "wateringAdvice": "string",
  "sunlightAdvice": "string",
  "recoveryPlan": ["string"],
  "needsRescan": false,
  "rescanAfterDays": 0
}}

Rules:
1. Confidence must be between 0 and 100.
2. Do not claim laboratory-level certainty.
3. If the image is unclear, status must be "Unclear".
4. If the plant appears healthy, disease must be "Healthy",
   status must be "Healthy", and severity must be "None".
5. Do not diagnose a disease from one ambiguous symptom alone.
6. Recommend practical home-gardening treatments.
7. Do not recommend dangerous chemical use.
8. Keep advice concise and useful.
9. Keep JSON keys exactly as written.
10. Keep status and severity in the canonical English categories.
"""

        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=[prompt, image],
        )

        result = safe_json(response.text)

        try:
            confidence = float(result.get("confidence", 0))
        except (TypeError, ValueError):
            confidence = 0.0

        result["confidence"] = max(0.0, min(100.0, confidence))

        defaults = {
            "plant": "Unknown",
            "disease": "Unclear",
            "status": "Unclear",
            "severity": "Unknown",
            "observations": [],
            "possibleCauses": [],
            "treatment": [],
            "prevention": [],
            "wateringAdvice": "",
            "sunlightAdvice": "",
            "recoveryPlan": [],
            "needsRescan": False,
            "rescanAfterDays": 0,
        }

        for key, default_value in defaults.items():
            if key not in result or result[key] is None:
                result[key] = default_value

        for key in (
            "observations",
            "possibleCauses",
            "treatment",
            "prevention",
            "recoveryPlan",
        ):
            result[key] = normalize_string_list(result[key])

        result["needsRescan"] = (
            result["needsRescan"] is True
            or str(result["needsRescan"]).lower() == "true"
        )

        try:
            result["rescanAfterDays"] = max(
                0,
                int(result["rescanAfterDays"]),
            )
        except (TypeError, ValueError):
            result["rescanAfterDays"] = 0

        return {
            "success": True,
            "language": selected_language,
            "analysis": result,
        }

    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(
            status_code=502,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        print("PLANT ANALYSIS ERROR:")
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail="Plant analysis failed. Please try again.",
        ) from exc


class AdvisorRequest(BaseModel):
    question: str
    plant: str = "Unknown"
    health: int = 100
    disease: str = "Healthy"
    garden_context: str = ""
    mode: str = "Garden"
    language: str = "English"


@app.post("/advisor")
async def advisor(request: AdvisorRequest):
    try:
        language = normalize_language(request.language)
        mode = request.mode.strip()

        if mode not in {"Garden", "Plant"}:
            mode = "Garden"

        question = request.question.strip()

        if not question:
            raise HTTPException(
                status_code=400,
                detail="Question cannot be empty.",
            )

        common_instructions = f"""
You are an AI urban gardening advisor.

{language_instruction(language)}

Give practical, safe, easy-to-understand advice.
Do not claim a laboratory diagnosis.
Do not recommend dangerous chemical use.
Do not invent details that are absent from the context.
Keep JSON field names exactly as specified.
"""

        if mode == "Plant":
            prompt = f"""
{common_instructions}

The user is asking about one specific plant.

Plant: {request.plant}
Current health score: {request.health}/100
Current disease status: {request.disease}

Garden context:
{request.garden_context.strip()}

User question:
{question}

Return ONLY valid JSON:
{{
  "answer": "string",
  "actions": ["string"],
  "warning": "string",
  "priority_plants": [],
  "garden_status": "Unknown",
  "when_to_rescan": "string"
}}

Give advice relevant to this plant.
"""

        else:
            prompt = f"""
{common_instructions}

The user is asking about their garden.

Garden context:
{request.garden_context.strip()}

User question:
{question}

Return ONLY valid JSON:
{{
  "answer": "string",
  "actions": ["string"],
  "warning": "string",
  "priority_plants": [
    {{
      "plant": "string",
      "reason": "string"
    }}
  ],
  "garden_status": "Healthy / Needs Attention / Critical / Unknown",
  "when_to_rescan": "string"
}}

Prioritize plants with poor health and mention watering or
disease concerns when relevant.
"""

        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=prompt,
        )

        result = safe_json(response.text)

        answer = result.get("answer", "")
        if not isinstance(answer, str):
            answer = str(answer)

        if not answer.strip():
            raise ValueError("The AI returned an empty advisor answer.")

        actions = normalize_string_list(result.get("actions"))

        warning = result.get("warning", "")
        if not isinstance(warning, str):
            warning = str(warning)

        raw_priority = result.get("priority_plants", [])
        if not isinstance(raw_priority, list):
            raw_priority = []

        priority_plants = []
        for item in raw_priority:
            if isinstance(item, dict):
                priority_plants.append({
                    "plant": str(item.get("plant", "")),
                    "reason": str(item.get("reason", "")),
                })

        return {
            "success": True,
            "advisor": {
                "answer": answer,
                "actions": [str(item) for item in actions],
                "warning": warning,
                "priority_plants": priority_plants,
                "garden_status": str(
                    result.get("garden_status", "Unknown")
                ),
                "when_to_rescan": str(
                    result.get("when_to_rescan", "")
                ),
                "language": language,
            },
        }

    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(
            status_code=502,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        print("ADVISOR ERROR:")
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail="Garden AI could not generate an answer. Please try again.",
        ) from exc
