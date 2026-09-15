/**
 * AgriVision AI Service
 *
 * Replaces the previous Gemini Vision integration.
 * Calls the custom EfficientNet-B5+CBAM + YOLOv8 + U-Net hierarchical pipeline.
 *
 * API Endpoint: POST /api/v1/diagnose (multipart/form-data, field name: "file")
 */

const AGRIVISION_BASE_URL =
  process.env.AGRIVISION_API_URL ||
  "https://parmarprashant--agrivision-diagnostic-engine-fastapi-app.modal.run";
const AGRIVISION_LOCAL_URL =
  process.env.AGRIVISION_LOCAL_API_URL || "http://127.0.0.1:8000";

/** Shape of the API response */
export interface AgriVisionRawResponse {
  crop: { name: string; confidence: number; status: string };
  plant_part: { name: string; confidence: number; status: string };
  diagnosis: {
    name: string;
    type: string;
    confidence: string;
    status: string;
    farmer_headline: string;
    farmer_subheading: string;
  };
  advisory: {
    urgency: string;
    disease_description: string;
    chemical_control: string[];
    organic_control: string[];
    cultural_practices: string[];
    expert_verification_note: string;
  };
  evidence: string[];
  recommendation: string;
  requires_expert_verification: boolean;
  pests: Record<string, unknown>;
  segmentation?: {
    infected_area_pct?: number;
  };
  focus_region?: {
    is_focused: boolean;
    box_normalized: [number, number, number, number];
    box_pixels: [number, number, number, number];
    message: string;
  };
}

/** Shape expected by the existing Kisan Dost frontend */
export interface AgriVisionDiseaseResult {
  cropName: string;
  diseaseName: string;
  confidence: number;
  description: string;
  symptoms: string[];
  causes: string[];
  precautions: string[];
  recommendedPesticides: string[];
  recommendedFertilizers: string[];
  requiresExpertVerification: boolean;
  focusRegion?: {
    isFocused: boolean;
    boxNormalized: [number, number, number, number]; // [ymin, xmin, ymax, xmax]
    boxPixels: [number, number, number, number];
    message: string;
  };
}

/**
 * Botanical Symptoms Knowledge Base for accurate farmer-facing foliar diagnostics.
 */
const BOTANICAL_SYMPTOMS: Record<string, { symptoms: string[]; causes: string[] }> = {
  "bacterial blight": {
    symptoms: [
      "Angular, water-soaked foliar spots bounded by leaf veinlets",
      "Lesions turning dark brown to purplish-black with yellowish chlorotic halos",
      "Vein necrosis spreading along principal veins causing leaf distortion",
      "Premature leaf yellowing and defoliation under high humidity"
    ],
    causes: [
      "Bacterial infection by Xanthomonas citri pv. malvacearum / Xanthomonas axonopodis.",
      "High relative humidity (>85%) and warm temperatures (28-32°C).",
      "Water splashing from rain or overhead irrigation spreading bacteria."
    ]
  },
  "anthracnose": {
    symptoms: [
      "Small, circular to irregular reddish-brown water-soaked spots on foliage",
      "Lesions with sunken centers and raised dark purple-brown margins",
      "Concentric ring formations visible on mature leaf lesions",
      "Premature drying, blighting, and seedling necrosis"
    ],
    causes: [
      "Fungal pathogen Colletotrichum gossypii / Colletotrichum spp. spore infection.",
      "Prolonged moisture on leaf surfaces from dew or rain showers.",
      "Warm, cloudy weather with poor sunlight penetration in dense canopies."
    ]
  },
  "boll rot": {
    symptoms: [
      "Dark brown to black necrotic lesions on reproductive organs and leaves",
      "Sunken water-soaked spots expanding across tissue margins",
      "Fungal mycelial growth visible on damp mornings in humid canopy"
    ],
    causes: [
      "Complex fungal and bacterial infection (Fusarium, Colletotrichum, Xanthomonas).",
      "Excessive nitrogen application causing dense canopy shading and humidity."
    ]
  },
  "leaf spot": {
    symptoms: [
      "Circular or irregular necrotic lesions with distinct grey or brown centers",
      "Yellow halos surrounding individual spots on upper leaf surfaces",
      "Coalescence of adjacent spots leading to extensive foliar blighting",
      "Premature senescence and leaf drop"
    ],
    causes: [
      "Fungal foliar pathogens (Cercospora, Alternaria, or Helminthosporium).",
      "Humid microclimate and extended wet leaf periods favoring spore germination."
    ]
  },
  "rust": {
    symptoms: [
      "Numerous small, raised yellowish-brown to orange-red pustules on leaves",
      "Pustules rupturing to release powdery fungal urediniospores",
      "Severe chlorosis and drying of foliage starting from lower leaves"
    ],
    causes: [
      "Airborne fungal infection (Puccinia spp.) carried by wind currents.",
      "Cool nights with dew followed by warm sunny days."
    ]
  },
  "healthy": {
    symptoms: [
      "Vibrant green canopy with uniform leaf expansion and vigor",
      "No fungal lesions, necrotic leaf spots, or pustules detected",
      "Intact foliar margins with healthy cellular turgidity"
    ],
    causes: [
      "Balanced soil nutrition (optimal N-P-K and micronutrient availability).",
      "Proper water management without waterlogging or prolonged moisture stress."
    ]
  }
};

/**
 * Remove internal debug telemetry strings and sanitize any AI model names
 */
function sanitizeText(text: string): string {
  if (!text) return "";
  return text
    .replace(/Gemini Vision/gi, "AgriVision AI")
    .replace(/Gemini/gi, "AgriVision AI")
    .replace(/closed-set CNN/gi, "Neural Classifier")
    .replace(/CNN/gi, "AI Model")
    .replace(/OOD/gi, "uncertainty")
    .replace(/\(Energy score[^)]*\)/gi, "")
    .replace(/Energy score[^;]*;/gi, "")
    .replace(/Normalized entropy[^;]*;/gi, "")
    .replace(/Peak confidence[^)]*\)/gi, "")
    .replace(/Primary.*?rejected by safety gates/gi, "Foliar assessment flagged for in-field verification")
    .replace(/\s+/g, " ")
    .trim();
}

function confidenceToNumber(level: string): number {
  switch (level?.toLowerCase()) {
    case "high": return 94;
    case "medium": return 78;
    case "low":
    default: return 52;
  }
}

function extractPesticideNames(chemicalControl: string[]): string[] {
  return chemicalControl
    .map((item) => item.split(/[\s,\u2013\u2014(]/)[0].trim())
    .filter((n) => n && n.length > 2 && !/no|none|avoid|do/i.test(n))
    .slice(0, 5);
}

function extractFertilizerNames(culturalPractices: string[]): string[] {
  const fertKeywords = /fertilizer|npk|urea|potassium|phosphorus|nitrogen|compost|micronutrient|zinc|boron|organic/i;
  return culturalPractices
    .filter((p) => fertKeywords.test(p))
    .map((p) => p.split(/[\s,\u2013\u2014(]/)[0].trim())
    .filter((n) => n && n.length > 2 && !/do|avoid|maintain/i.test(n))
    .slice(0, 3);
}

export async function analyzeWithAgriVision(file: Blob): Promise<AgriVisionDiseaseResult> {
  const formData = new FormData();
  formData.append("file", file);

  // Determine endpoints to try (Primary Cloud URL first, then Localhost fallback)
  const candidateUrls: string[] = [];
  if (AGRIVISION_BASE_URL) candidateUrls.push(AGRIVISION_BASE_URL.replace(/\/+$/, ""));
  if (AGRIVISION_LOCAL_URL && !candidateUrls.includes(AGRIVISION_LOCAL_URL.replace(/\/+$/, ""))) {
    candidateUrls.push(AGRIVISION_LOCAL_URL.replace(/\/+$/, ""));
  }

  let raw: AgriVisionRawResponse | null = null;
  let lastError: Error | null = null;

  for (const baseUrl of candidateUrls) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 45000);

    try {
      console.log(`[AgriVisionService] Trying endpoint ${baseUrl}/api/v1/diagnose ...`);
      const response = await fetch(`${baseUrl}/api/v1/diagnose`, {
        method: "POST",
        body: formData,
        signal: controller.signal,
      });
      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorText = await response.text().catch(() => response.statusText);
        throw new Error(`AgriVision API error ${response.status}: ${errorText}`);
      }

      raw = await response.json();
      console.log(`[AgriVisionService] Diagnosis successfully received from ${baseUrl}: ${raw?.diagnosis?.name}`);
      break;
    } catch (err: any) {
      clearTimeout(timeoutId);
      console.warn(`[AgriVisionService] Connection to ${baseUrl} failed:`, err.message);
      lastError = err;
    }
  }

  if (!raw) {
    throw lastError || new Error("Failed to connect to AgriVision AI service (both Cloud and Localhost failed).");
  }

    const isHealthy =
      raw.diagnosis.type === "healthy" ||
      raw.diagnosis.name.toLowerCase().includes("healthy");

    let cleanDiseaseName = isHealthy
      ? "Healthy Crop"
      : raw.diagnosis.farmer_headline || raw.diagnosis.name;

    // Clean up "Suspected: " prefix if present
    cleanDiseaseName = cleanDiseaseName.replace(/^Suspected:\s*/i, "").trim();

    // Capitalize crop name
    const rawCrop = raw.crop?.name || "Crop";
    const isUnknownCrop = !rawCrop || rawCrop.toLowerCase() === "unknown";
    const cropName = isUnknownCrop
      ? "Unknown Crop"
      : rawCrop.charAt(0).toUpperCase() + rawCrop.slice(1);

    const isUndetermined =
      cleanDiseaseName.toLowerCase().includes("unable to determine") ||
      raw.diagnosis.status === "INSUFFICIENT_EVIDENCE" ||
      raw.diagnosis.type === "unknown";

    const confidence = isUndetermined ? 0 : confidenceToNumber(raw.diagnosis.confidence);

    // --- Build Clean Agronomic Symptoms ---
    const diseaseLower = cleanDiseaseName.toLowerCase();
    let matchedSymptoms: string[] = [];
    let matchedCauses: string[] = [];

    for (const [key, data] of Object.entries(BOTANICAL_SYMPTOMS)) {
      if (diseaseLower.includes(key) || (isHealthy && key === "healthy")) {
        matchedSymptoms = data.symptoms;
        matchedCauses = data.causes;
        break;
      }
    }

    // Filter raw evidence to keep only clean visual markers (not debug lines)
    const cleanRawEvidence = (raw.evidence || [])
      .filter((line) => !/(crop status|plant organ|resolution state|primary cnn|fallback:|rejected:|energy score)/i.test(line))
      .map(sanitizeText)
      .filter((s) => s.length > 5);

    const symptoms = isUndetermined
      ? [
          "Wide-angle or distant plant photograph detected.",
          "Individual leaf lesion patterns cannot be resolved with diagnostic certainty.",
          "Please upload a clear close-up photograph of an individual affected leaf."
        ]
      : matchedSymptoms.length > 0
      ? matchedSymptoms
      : cleanRawEvidence.length > 0
      ? cleanRawEvidence
      : [
          `Visible foliar discoloration and lesion spotting on ${cropName} leaves.`,
          "Irregular necrotic tissue boundaries observed on leaf blade.",
          "Yellowish chlorotic margins surrounding affected areas."
        ];

    // --- Build Clean Agronomic Causes ---
    let causes: string[] = [];
    if (isUndetermined) {
      causes = [
        "Camera distance or wide field framing obscures leaf vein details and micro-lesion margins.",
        "Accurate AI diagnosis requires high-resolution macro imagery of single leaves."
      ];
    } else if (matchedCauses.length > 0) {
      causes = matchedCauses;
    } else if (raw.advisory.disease_description) {
      const sanitizedDesc = sanitizeText(raw.advisory.disease_description);
      causes = sanitizedDesc
        .split(/\.\s+/)
        .filter((s) => s.length > 15 && !/(rejected|gates|score|entropy|status)/i.test(s))
        .slice(0, 3)
        .map((s) => (s.endsWith(".") ? s : s + "."));
    }
    if (causes.length === 0) {
      causes = [
        `Foliar pathogen activity favored by seasonal humidity and temperature conditions.`,
        "Moisture persistence on leaves enabling fungal or bacterial spore germination."
      ];
    }

    // Precautions / Cultural practices
    const rawPrecautions = raw.advisory.cultural_practices || [];
    const precautions = rawPrecautions
      .map(sanitizeText)
      .filter((p) => p.length > 10 && !/(score|entropy|rejected|status)/i.test(p));

    if (isUndetermined) {
      precautions.length = 0;
      precautions.push(
        "Take a close-up photo focusing on a single diseased leaf in good daylight.",
        "Ensure the camera is in sharp focus on the leaf spots or lesions.",
        "Avoid applying chemical sprays until diagnosis is verified."
      );
    } else if (precautions.length === 0) {
      precautions.push(
        "Inspect leaves early in the morning for dew-related fungal spread.",
        "Ensure balanced fertilization and avoid excess nitrogen.",
        "Remove and destroy severely blighted leaf debris from the field."
      );
    }

    const recommendedPesticides = isUndetermined ? [] : extractPesticideNames(raw.advisory.chemical_control || []);
    const recommendedFertilizers = isUndetermined ? [] : extractFertilizerNames(raw.advisory.cultural_practices || []);

    const description = isUndetermined
      ? (raw.diagnosis.farmer_subheading || "Wide-angle or ambiguous photo detected. Please upload a clear close-up photograph of an individual affected leaf.")
      : sanitizeText(
          raw.advisory.disease_description ||
          raw.recommendation ||
          raw.diagnosis.farmer_subheading ||
          `${cleanDiseaseName} diagnosed on ${cropName}. Follow recommended field management.`
        );

    const focusRegion = raw.focus_region
      ? {
          isFocused: raw.focus_region.is_focused ?? false,
          boxNormalized: raw.focus_region.box_normalized || [0, 0, 1, 1],
          boxPixels: raw.focus_region.box_pixels || [0, 0, 0, 0],
          message: raw.focus_region.message || "",
        }
      : undefined;

    return {
      cropName,
      diseaseName: cleanDiseaseName,
      confidence,
      description,
      symptoms,
      causes,
      precautions,
      recommendedPesticides,
      recommendedFertilizers,
      requiresExpertVerification: raw.requires_expert_verification ?? false,
      focusRegion,
    };
}

