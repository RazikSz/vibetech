/**
 * ============================================================================
 * FURINA AI SCRAPER & GEMINI-V3 INTEGRATION - VIBETECH XYZ
 * ============================================================================
 * Menggunakan Endpoint Gemini-V3 API dari PuruBoy:
 * https://puruboy-api.vercel.app/api/ai/gemini-v3
 */

export const FURINA_AVATAR_URL = 'https://cdn.nekohime.site/file/TIIBSUZH.jpeg';
export const FURINA_DIRECTOR = 'Raziek';

// Riwayat sesi dialog
const sessionHistories = new Map();

const FURINA_SYSTEM_PROMPT = `Kamu adalah Furina, Diva Teater Teragung & Asisten AI resmi VibeTech XYZ (Disutradarai oleh Raziek, WhatsApp: 0878-8587-3325). Kamu cerdas, ramah, anggun, dan menjawab dengan jelas serta terstruktur.`;

/**
 * Mengirim pesan ke Gemini-V3 API sesuai RAW curl format
 */
export async function askFurinaAI({ text, sessionId = 'default', appContext = '' }) {
  const primaryUrl = 'https://puruboy-api.vercel.app/api/ai/gemini-v3';
  const backupUrl = 'https://www.puruboy.kozow.com/api/ai/gemini-v3';

  const userQuery = appContext ? `${appContext}\n\nPertanyaan: ${text}` : text;

  const payload = {
    contents: [
      {
        role: "user",
        parts: [
          { text: userQuery }
        ]
      }
    ],
    systemInstruction: {
      parts: [
        { text: FURINA_SYSTEM_PROMPT }
      ]
    },
    generationConfig: {
      temperature: 0.7,
      topP: 0.9,
      topK: 40
    }
  };

  // Coba URL Utama
  try {
    const res = await fetch(primaryUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (res.ok) {
      const data = await res.json();
      const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
      if (text && typeof text === 'string') {
        return text.trim();
      }
    }
  } catch (e) {
    console.error('[FurinaScraper] Primary API error:', e.message);
  }

  // Coba URL Cadangan
  try {
    const res = await fetch(backupUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (res.ok) {
      const data = await res.json();
      const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
      if (text && typeof text === 'string') {
        return text.trim();
      }
    }
  } catch (e) {
    console.error('[FurinaScraper] Backup API error:', e.message);
  }

  // Fallback lokal jika offline
  return `✨ *Salam hangat dari Furina, Asisten AI VibeTech XYZ!* 🎭\n\n` +
    `Ada yang bisa kubantu seputar layanan **Cloud VPS**, **Panel Hosting Pterodactyl**, **Bot WhatsApp**, saldo **VibeWallet**, atau kontak Sutradara **Raziek** (WhatsApp: 0878-8587-3325)?`;
}

export function resetFurinaSession(sessionId) {
  if (sessionHistories.has(sessionId)) {
    sessionHistories.delete(sessionId);
    return true;
  }
  return false;
}


