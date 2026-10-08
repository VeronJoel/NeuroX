import io
import json
import os
import traceback

from dotenv import load_dotenv
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from google import genai
from PIL import Image
from pydantic import BaseModel


# ==========================================================
# ENVIRONMENT
# ==========================================================

load_dotenv()

API_KEY = os.getenv("GEMINI_API_KEY")

if not API_KEY:
    raise RuntimeError(
        "GEMINI_API_KEY was not found in .env"
    )


# ==========================================================
# GEMINI
# ==========================================================

client = genai.Client(
    api_key=API_KEY
)

MODEL_NAME = "gemini-3.5-flash"


# ==========================================================
# FASTAPI
# ==========================================================

app = FastAPI(
    title="Urban Farming AI Backend",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ==========================================================
# LANGUAGE SUPPORT
# ==========================================================

LANGUAGES = {
    "English": "English",
    "Hindi": "Hindi",
    "Gujarati": "Gujarati",
    "Marathi": "Marathi",
    "Bengali": "Bengali",
    "Tamil": "Tamil",
    "Telugu": "Telugu",
    "Kannada": "Kannada",
}


def normalize_language(language: str) -> str:
    language = (language or "English").strip()

    if language in LANGUAGES:
        return LANGUAGES[language]

    return "English"


# ==========================================================
# JSON HELPER
# ==========================================================

def safe_json(text: str) -> dict:
    """
    Converts Gemini response into a Python dictionary.
    Handles markdown JSON code blocks.
    """

    if not text:
        return {
            "answer": "",
            "actions": [],
            "warning": "",
            "priority_plants": [],
            "garden_status": "Unknown",
            "when_to_rescan": "",
        }

    text = text.strip()

    if text.startswith("```"):
        if text.startswith("```json"):
            text = text[7:]
        elif text.startswith("```"):
            text = text[3:]

        if text.endswith("```"):
            text = text[:-3]

        text = text.strip()

    try:
        return json.loads(text)

    except Exception:
        return {
            "answer": text,
            "actions": [],
            "warning": "",
            "priority_plants": [],
            "garden_status": "Unknown",
            "when_to_rescan": "",
        }


# ==========================================================
# ROOT
# ==========================================================

@app.get("/")
def root():
    return {
        "status": "online",
        "service": "Urban Farming AI",
        "model": MODEL_NAME,
    }


# ==========================================================
# HEALTH
# ==========================================================

@app.get("/health")
def health():
    return {
        "status": "healthy",
        "ai": "ready",
        "model": MODEL_NAME,
    }


# ==========================================================
# PLANT IMAGE ANALYSIS
# ==========================================================

@app.post("/analyze")
async def analyze_plant(
    file: UploadFile = File(...),
):
    try:

        # --------------------------------------------------
        # Read uploaded file
        # --------------------------------------------------

        image_bytes = await file.read()

        if not image_bytes:
            raise HTTPException(
                status_code=400,
                detail="Empty image.",
            )

        # --------------------------------------------------
        # Open and validate actual image format
        #
        # We intentionally DO NOT rely only on
        # file.content_type because Android/Flutter can
        # sometimes send application/octet-stream.
        # --------------------------------------------------

        try:
            image = Image.open(
                io.BytesIO(image_bytes)
            )

            image_format = image.format

            allowed_formats = {
                "JPEG",
                "PNG",
                "WEBP",
            }

            if image_format not in allowed_formats:
                raise HTTPException(
                    status_code=400,
                    detail=(
                        "Please upload a JPG, PNG, "
                        "or WEBP image."
                    ),
                )

            # Convert to RGB for Gemini
            image = image.convert("RGB")

        except HTTPException:
            raise

        except Exception:
            raise HTTPException(
                status_code=400,
                detail=(
                    "The uploaded file is not a valid "
                    "JPG, PNG, or WEBP image."
                ),
            )

        # --------------------------------------------------
        # Gemini prompt
        # --------------------------------------------------

        prompt = """
You are an AI urban farming assistant.

Analyze the uploaded plant image.

Return ONLY valid JSON using exactly this structure:

{
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
}

Rules:

1. confidence must be between 0 and 100.
2. Do not claim laboratory-level certainty.
3. If the image is unclear, use "Unclear".
4. If the plant appears healthy, disease should be "Healthy".
5. Treatment should be practical for home or urban gardening.
6. Do not recommend dangerous chemicals.
7. Keep recommendations concise.
"""

        # --------------------------------------------------
        # Gemini request
        # --------------------------------------------------

        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=[
                prompt,
                image,
            ],
        )

        result = safe_json(
            response.text
        )

        # --------------------------------------------------
        # Confidence normalization
        # --------------------------------------------------

        confidence = result.get(
            "confidence",
            0,
        )

        try:
            confidence = float(
                confidence
            )

        except Exception:
            confidence = 0

        confidence = max(
            0,
            min(
                100,
                confidence,
            ),
        )

        result["confidence"] = confidence

        # --------------------------------------------------
        # Return result
        # --------------------------------------------------

        return {
            "success": True,
            "analysis": result,
        }

    except HTTPException:
        raise

    except Exception as e:
        print(
            "PLANT ANALYSIS ERROR:"
        )

        traceback.print_exc()

        raise HTTPException(
            status_code=500,
            detail=str(e),
        )


# ==========================================================
# ADVISOR REQUEST MODEL
# ==========================================================

class AdvisorRequest(BaseModel):
    question: str
    plant: str = "Unknown"
    health: int = 100
    disease: str = "Healthy"
    garden_context: str = ""
    mode: str = "Garden"
    language: str = "English"


# ==========================================================
# AI ADVISOR
# ==========================================================

@app.post("/advisor")
async def advisor(
    request: AdvisorRequest,
):
    try:

        # --------------------------------------------------
        # Normalize language
        # --------------------------------------------------

        language = normalize_language(
            request.language
        )

        # --------------------------------------------------
        # Normalize mode
        # --------------------------------------------------

        mode = request.mode.strip()

        if mode not in [
            "Garden",
            "Plant",
        ]:
            mode = "Garden"

        # --------------------------------------------------
        # Validate question
        # --------------------------------------------------

        question = request.question.strip()

        if not question:
            raise HTTPException(
                status_code=400,
                detail="Question cannot be empty.",
            )

        # --------------------------------------------------
        # Garden context
        # --------------------------------------------------

        garden_context = (
            request.garden_context.strip()
        )

        # ==================================================
        # LANGUAGE INSTRUCTION
        # ==================================================

        language_instruction = f"""
Respond completely in {language}.

The user selected {language} as their preferred language.

Use natural, easy-to-understand language suitable
for a normal urban gardener.

Do not unnecessarily mix English into the response.

Plant names may remain in English when that makes
them clearer.

Technical gardening terms can include the English
term in parentheses when useful.
"""

        # ==================================================
        # PLANT MODE
        # ==================================================

        if mode == "Plant":

            prompt = f"""
You are an AI plant-care advisor.

{language_instruction}

The user is asking about one specific plant.

Plant:

{request.plant}

Current health score:

{request.health}/100

Current disease status:

{request.disease}

Garden context:

{garden_context}

User question:

{question}

Give practical, safe advice.

Return ONLY valid JSON:

{{
  "answer": "string",
  "actions": [
    "string"
  ],
  "warning": "string",
  "priority_plants": [],
  "garden_status": "Unknown",
  "when_to_rescan": "string"
}}

Rules:

- Be practical.
- Do not pretend to provide laboratory diagnosis.
- Do not recommend dangerous chemical usage.
- Mention professional/agricultural help when the situation
  appears serious.
- Keep the answer understandable.
"""

        # ==================================================
        # GARDEN MODE
        # ==================================================

        else:

            prompt = f"""
You are an AI urban garden advisor.

{language_instruction}

The user is asking about their entire garden.

Garden context:

{garden_context}

User question:

{question}

Analyze the available garden information and provide
useful recommendations.

Return ONLY valid JSON:

{{
  "answer": "string",
  "actions": [
    "string"
  ],
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

Rules:

- Prioritize plants with poor health.
- Mention watering or disease issues when relevant.
- Keep recommendations realistic for urban gardening.
- Do not invent plant information that is not present
  in the supplied context.
- Do not recommend dangerous chemicals.
- Keep the answer practical.
"""

        # ==================================================
        # GEMINI REQUEST
        # ==================================================

        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=prompt,
        )

        result = safe_json(
            response.text
        )

        # ==================================================
        # NORMALIZE RESPONSE
        # ==================================================

        answer = result.get(
            "answer",
            "",
        )

        actions = result.get(
            "actions",
            [],
        )

        warning = result.get(
            "warning",
            "",
        )

        priority_plants = result.get(
            "priority_plants",
            [],
        )

        garden_status = result.get(
            "garden_status",
            "Unknown",
        )

        when_to_rescan = result.get(
            "when_to_rescan",
            "",
        )

        # --------------------------------------------------
        # Ensure actions is a list
        # --------------------------------------------------

        if not isinstance(
            actions,
            list,
        ):
            actions = []

        # --------------------------------------------------
        # Ensure priority plants is a list
        # --------------------------------------------------

        if not isinstance(
            priority_plants,
            list,
        ):
            priority_plants = []

        normalized_priority = []

        for item in priority_plants:

            if isinstance(
                item,
                dict,
            ):
                normalized_priority.append(
                    {
                        "plant": str(
                            item.get(
                                "plant",
                                "",
                            )
                        ),
                        "reason": str(
                            item.get(
                                "reason",
                                "",
                            )
                        ),
                    }
                )

        # --------------------------------------------------
        # Return advisor response
        # --------------------------------------------------

        return {
            "success": True,
            "advisor": {
                "answer": str(
                    answer
                ),
                "actions": [
                    str(item)
                    for item in actions
                ],
                "warning": str(
                    warning
                ),
                "priority_plants":
                    normalized_priority,
                "garden_status":
                    str(
                        garden_status
                    ),
                "when_to_rescan":
                    str(
                        when_to_rescan
                    ),
                "language":
                    language,
            },
        }

    except HTTPException:
        raise

    except Exception as e:
        print(
            "ADVISOR ERROR:"
        )

        traceback.print_exc()

        raise HTTPException(
            status_code=500,
            detail=str(e),
        )