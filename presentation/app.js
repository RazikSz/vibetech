/**
 * ==========================================================================
 * CANVA-STYLE PRESENTATION ENGINE - VIBETECH XYZ (16 SLIDES)
 * Developer: Raziek | Interactive Slideshow, Code Tabs, Notes & Shortcuts
 * ==========================================================================
 */

document.addEventListener('DOMContentLoaded', () => {
  // --- STATE VARIABLES ---
  const slides = document.querySelectorAll('.slide');
  const totalSlides = slides.length;
  let currentSlideIndex = 0;
  let isFullscreen = false;
  let isNotesOpen = false;
  let isDrawerOpen = false;

  // DOM Elements
  const currentNumEl = document.getElementById('current-slide-num');
  const totalNumEl = document.getElementById('total-slide-num');
  const progressFillEl = document.getElementById('deck-progress-fill');
  const prevBtn = document.getElementById('btn-prev');
  const nextBtn = document.getElementById('btn-next');
  const fullscreenBtn = document.getElementById('btn-fullscreen');
  const notesBtn = document.getElementById('btn-notes');
  const drawerBtn = document.getElementById('btn-drawer');
  const closeNotesBtn = document.getElementById('btn-close-notes');
  const notesModal = document.getElementById('speaker-notes-modal');
  const notesContentEl = document.getElementById('notes-content-body');
  const notesTitleEl = document.getElementById('notes-slide-title');
  const thumbDrawer = document.getElementById('thumb-drawer');
  const thumbList = document.getElementById('thumb-list');

  // Set Total Slides Counter
  if (totalNumEl) totalNumEl.textContent = totalSlides;

  // --- SPEAKER NOTES DATABASE (20 SLIDES) ---
  const speakerNotes = [
    {
      title: "Slide 1: Cover & Hero",
      content: "Sambut audiens. Kenalkan VibeTech XYZ v2.0.0 sebagai platform ekosistem cloud infrastructure cerdas multi-platform (Cloud VPS, Panel Pterodactyl, Bot WhatsApp, dan Furina AI Assistant yang disutradarai oleh Raziek). Sorot integrasi Flutter, SQLite, Express ESM, dan Midtrans."
    },
    {
      title: "Slide 2: Melanjutkan Ide Proposal Awal",
      content: "Jelaskan bagaimana proyek ini melanjutkan visi proposal awal: digitalisasi akses server bagi developer dan komunitas gamer, serta peningkatan sistem ke arsitektur mobile offline-first dengan dompet digital VibeWallet."
    },
    {
      title: "Slide 3: Perubahan Arah (Pivot) dari Ide Awal",
      content: "Sorot 4 pilar pivot utama: (1) Dari setup manual ke Instant Auto-Provisioning, (2) Dari single transfer ke Dual Checkout VibeWallet & Midtrans Snap, (3) Dari form kaku ke Theatrical Furina AI dengan dynamic DB context, (4) Penambahan keamanan biometrik hardware."
    },
    {
      title: "Slide 4: Screenshot Fitur Utama (Part 1)",
      content: "Tampilkan 3 tangkapan layar fitur utama: (1) Interactive Dashboard dengan kartu saldo VibeWallet Rp 10 Juta & 4-Grid Quick Actions, (2) Katalog Produk Cloud VPS/Panel SG/Bot WA, dan (3) Sistem Pembayaran Dual Checkout Saldo VibeWallet 1-klik dengan PIN 2FA."
    },
    {
      title: "Slide 5: Screenshot Fitur Utama (Part 2)",
      content: "Tampilkan 3 tangkapan layar fitur utama: (4) Keranjang Belanja dengan kuantitas dinamis & kupon diskon 30%, (5) Profil Pengguna dengan toggle bahasa ID/EN & biometrik 2FA, serta (6) Data Kredensial Server (Kartu Layanan) dengan IP, SSH port, dan toggle visibilitas root password."
    },
    {
      title: "Slide 6: Fitur Utama Aplikasi",
      content: "Paparkan 6 pilar fungsionalitas utama: (1) Interactive Dashboard & Wallet, (2) Produk Cloud & Server, (3) Pembayaran Instan VibeWallet, (4) Keranjang Belanja & Diskon Promo, (5) Profil & Keamanan 2FA, dan (6) Data Kredensial Server SQLite."
    },
    {
      title: "Slide 7: Keunggulan Kompetitif & Value Proposition",
      content: "Tekankan 6 keunggulan pembeda: Penerbitan kredensial instan 1 detik, Dual payment otomatis, Keamanan hardware biometrik, AI kontekstual database, arsitektur offline-first, dan UI Cyberpunk premium."
    },
    {
      title: "Slide 8: Arsitektur Sistem 4-Lapis",
      content: "Bedah 4 lapisan arsitektur: Flutter Presentation Layer, State & Business Logic (CartService & Notifiers), SQLite Persistence Layer, dan Backend Microservices (Express ESM & External API)."
    },
    {
      title: "Slide 9: Siklus Alur Database (Database Lifecycle)",
      content: "Jelaskan alur data 5 tahap: Registrasi user -> Query produk & cart -> Eksekusi pembayaran saldo/Midtrans -> Generasi kredensial otomatis di purchased_services -> Notifikasi in-app & renewal masa aktif."
    },
    {
      title: "Slide 10: Skema Relasional SQLite & DDL",
      content: "Bedah relasi tabel users, products, transactions, purchased_services, dan notifications. Tunjukkan cuplikan kode DDL create table pada database_helper.dart."
    },
    {
      title: "Slide 11: Penjelasan Lengkap CRUD Database",
      content: "Jelaskan secara mendalam implementasi CRUD pada SQLite: CREATE (insert produk, transaksi, server instance, notif), READ (query katalog, riwayat user, filter kategori), UPDATE (edit produk, deduksi saldo, status transaksi, perpanjang server), dan DELETE (hapus produk dengan konfirmasi dialog, bersihkan notif)."
    },
    {
      title: "Slide 12: Modul Keamanan Biometrik & 2FA",
      content: "Jelaskan implementasi keamanan hardware: Biometrik LocalAuthentication (Fingerprint/FaceID), fallback PIN 6-digit, dan hashing password SHA-256."
    },
    {
      title: "Slide 13: Modul E-Commerce, Keranjang & Diskon",
      content: "Jelaskan modul belanja: CartService berbasis ValueNotifier, multi-category filter, kalkulasi harga real-time berdasarkan durasi sewa, dan sistem kupon promo diskon."
    },
    {
      title: "Slide 14: Modul Dual Payment Gateway",
      content: "Jelaskan alur pembayaran instan potong Saldo VibeWallet vs Payment Gateway Midtrans Snap (QRIS, VA Bank BCA/Mandiri/BRI, E-Wallet) via endpoint /api/charge."
    },
    {
      title: "Slide 15: Modul Auto-Provisioning Server",
      content: "Tunjukkan bagaimana sistem membuat instance kredensial VPS (IP, SSH Port, Root Pass) dan link Pterodactyl secara instan dengan countdown timer masa aktif."
    },
    {
      title: "Slide 16: Modul Riwayat Transaksi & Invoicing",
      content: "Jelaskan struktur penomoran invoice standar (INV-YYYYMMDD-XXXX), status tracking badge real-time, dan digital receipt modal untuk transparansi audit transaksi."
    },
    {
      title: "Slide 17: Modul Notifikasi, Tema & Multi-Bahasa",
      content: "Jelaskan fitur personalisasi: In-app notification center, theme switch Dark/Light mode, dan multi-language support (ID/EN) via LanguageService."
    },
    {
      title: "Slide 18: Modul Furina AI Assistant & Scraper",
      content: "Sorot Furina AI karya Raziek: Terintegrasi dengan scraper ESM, WhatsApp handler, context injection otomatis dari database (WhatsApp: 0878-8587-3325, developer Raziek, saldo user), serta fallback cerdas ke Gemini."
    },
    {
      title: "Slide 19: Backend API Microservices (Express ESM)",
      content: "Tampilkan tabel REST endpoint Express.js: POST /api/ai/chat, POST /api/charge, GET /api/status/:order_id, dan POST /api/ai/reset-session."
    },
    {
      title: "Slide 20: Roadmap, Tech Stack & Sesi Q&A",
      content: "Tutup presentasi dengan roadmap Q1-Q3 2026 (Auto-scaling cluster, Web CLI, AI diagnostics), kontak WhatsApp resmi 0878-8587-3325, developer Raziek, dan buka sesi tanya jawab (Q&A)."
    }
  ];

  // --- POPULATE THUMBNAIL DRAWER ---
  function initThumbnailDrawer() {
    if (!thumbList) return;
    thumbList.innerHTML = '';
    slides.forEach((slide, index) => {
      const slideTitle = slide.querySelector('.slide-title')?.textContent || 
                         slide.querySelector('.hero-main-title')?.textContent || 
                         `Slide ${index + 1}`;
      
      const thumbItem = document.createElement('div');
      thumbItem.className = `thumb-item ${index === 0 ? 'active' : ''}`;
      thumbItem.innerHTML = `
        <div class="thumb-num">SLIDE ${String(index + 1).padStart(2, '0')}</div>
        <div class="thumb-title">${slideTitle.replace(/[\n\r]+/g, ' ').trim()}</div>
      `;
      thumbItem.addEventListener('click', () => {
        goToSlide(index);
        toggleDrawer(false);
      });
      thumbList.appendChild(thumbItem);
    });
  }

  // --- SLIDE NAVIGATION FUNCTIONS ---
  function goToSlide(index) {
    if (index < 0 || index >= totalSlides) return;

    // Deactivate current slide
    slides[currentSlideIndex].classList.remove('active');

    // Update index
    currentSlideIndex = index;

    // Activate new slide
    slides[currentSlideIndex].classList.add('active');

    // Update Counter & Progress Bar
    if (currentNumEl) currentNumEl.textContent = currentSlideIndex + 1;
    const progressPercent = ((currentSlideIndex + 1) / totalSlides) * 100;
    if (progressFillEl) progressFillEl.style.width = `${progressPercent}%`;

    // Update Prev/Next Buttons state
    if (prevBtn) prevBtn.disabled = currentSlideIndex === 0;
    if (nextBtn) {
      if (currentSlideIndex === totalSlides - 1) {
        nextBtn.innerHTML = 'Selesai <i class="fas fa-check"></i>';
      } else {
        nextBtn.innerHTML = 'Next <i class="fas fa-chevron-right"></i>';
      }
    }

    // Update Thumbnails Active State
    const thumbItems = document.querySelectorAll('.thumb-item');
    thumbItems.forEach((item, idx) => {
      item.classList.toggle('active', idx === currentSlideIndex);
    });

    // Update Speaker Notes Content
    updateSpeakerNotes();
  }

  function nextSlide() {
    if (currentSlideIndex < totalSlides - 1) {
      goToSlide(currentSlideIndex + 1);
    }
  }

  function prevSlide() {
    if (currentSlideIndex > 0) {
      goToSlide(currentSlideIndex - 1);
    }
  }

  // --- SPEAKER NOTES TOGGLE ---
  function updateSpeakerNotes() {
    const note = speakerNotes[currentSlideIndex];
    if (note && notesContentEl && notesTitleEl) {
      notesTitleEl.textContent = note.title;
      notesContentEl.innerHTML = `<p>${note.content}</p>`;
    }
  }

  function toggleNotes(force) {
    isNotesOpen = typeof force === 'boolean' ? force : !isNotesOpen;
    if (notesModal) {
      notesModal.classList.toggle('active', isNotesOpen);
    }
  }

  function toggleDrawer(force) {
    isDrawerOpen = typeof force === 'boolean' ? force : !isDrawerOpen;
    if (thumbDrawer) {
      thumbDrawer.classList.toggle('active', isDrawerOpen);
    }
  }

  function toggleFullscreen() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().catch(err => console.log(err));
      isFullscreen = true;
    } else {
      if (document.exitFullscreen) {
        document.exitFullscreen();
        isFullscreen = false;
      }
    }
  }

  // --- CODE TABS SWITCHER ---
  function initCodeTabs() {
    const tabGroups = document.querySelectorAll('.code-box');
    tabGroups.forEach(box => {
      const tabs = box.querySelectorAll('.code-tab');
      const snippets = box.querySelectorAll('.code-snippet');
      tabs.forEach((tab, index) => {
        tab.addEventListener('click', () => {
          tabs.forEach(t => t.classList.remove('active'));
          snippets.forEach(s => s.style.display = 'none');
          tab.classList.add('active');
          if (snippets[index]) {
            snippets[index].style.display = 'block';
          }
        });
      });
    });
  }

  // --- KEYBOARD SHORTCUTS ---
  document.addEventListener('keydown', (e) => {
    switch (e.key) {
      case 'ArrowRight':
      case 'Space':
      case 'PageDown':
        e.preventDefault();
        nextSlide();
        break;
      case 'ArrowLeft':
      case 'Backspace':
      case 'PageUp':
        e.preventDefault();
        prevSlide();
        break;
      case 'f':
      case 'F':
        toggleFullscreen();
        break;
      case 'n':
      case 'N':
        toggleNotes();
        break;
      case 'g':
      case 'G':
        toggleDrawer();
        break;
      case 'Escape':
        toggleNotes(false);
        toggleDrawer(false);
        break;
      case 'Home':
        goToSlide(0);
        break;
      case 'End':
        goToSlide(totalSlides - 1);
        break;
    }
  });

  // Event Listeners for UI Buttons
  if (prevBtn) prevBtn.addEventListener('click', prevSlide);
  if (nextBtn) nextBtn.addEventListener('click', nextSlide);
  if (fullscreenBtn) fullscreenBtn.addEventListener('click', toggleFullscreen);
  if (notesBtn) notesBtn.addEventListener('click', () => toggleNotes());
  if (closeNotesBtn) closeNotesBtn.addEventListener('click', () => toggleNotes(false));
  if (drawerBtn) drawerBtn.addEventListener('click', () => toggleDrawer());

  // --- PARTICLES CANVAS BACKGROUND ---
  function initParticles() {
    const canvas = document.getElementById('particles-canvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let width = canvas.width = window.innerWidth;
    let height = canvas.height = window.innerHeight;

    window.addEventListener('resize', () => {
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    });

    const particles = [];
    const numParticles = 45;

    for (let i = 0; i < numParticles; i++) {
      particles.push({
        x: Math.random() * width,
        y: Math.random() * height,
        radius: Math.random() * 2 + 1,
        vx: (Math.random() - 0.5) * 0.4,
        vy: (Math.random() - 0.5) * 0.4,
        color: i % 3 === 0 ? 'rgba(124, 77, 255, 0.4)' : (i % 3 === 1 ? 'rgba(224, 64, 251, 0.4)' : 'rgba(0, 229, 255, 0.3)')
      });
    }

    function animateParticles() {
      ctx.clearRect(0, 0, width, height);
      particles.forEach(p => {
        p.x += p.vx;
        p.y += p.vy;

        if (p.x < 0) p.x = width;
        if (p.x > width) p.x = 0;
        if (p.y < 0) p.y = height;
        if (p.y > height) p.y = 0;

        ctx.beginPath();
        ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
        ctx.fillStyle = p.color;
        ctx.fill();
      });
      requestAnimationFrame(animateParticles);
    }
    animateParticles();
  }

  // --- INITIALIZE ALL ---
  initThumbnailDrawer();
  initCodeTabs();
  initParticles();
  goToSlide(0);
});
