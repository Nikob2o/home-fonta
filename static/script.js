// === Ajout automatique du favicon sur toutes les pages ===
document.addEventListener("DOMContentLoaded", () => {
  if (!document.querySelector('link[rel="icon"]')) {
    const favicon = document.createElement("link");
    favicon.rel = "icon";
    favicon.href = "/static/images/ours.jpg";
    favicon.type = "image/png";
    document.head.appendChild(favicon);
  }
});

// === LIGHTBOX POUR GALERIE ===
document.addEventListener("DOMContentLoaded", () => {
  const images = document.querySelectorAll(".gallery-fullscreen img");
  const lightbox = document.getElementById("lightbox");
  const lightboxImg = document.getElementById("lightbox-img");
  
  if (!images.length || !lightbox || !lightboxImg) return;
  
  let currentIndex = 0;
  
  function showImage() {
    lightboxImg.src = images[currentIndex].src;
  }
  
  function openLightbox(index) {
    currentIndex = index;
    showImage();
    lightbox.classList.add("show");
  }
  
  function closeLightbox() {
    lightbox.classList.remove("show");
  }
  
  function changeImage(step) {
    currentIndex = (currentIndex + step + images.length) % images.length;
    showImage();
  }
  
  images.forEach((img, index) => {
    img.addEventListener("click", () => openLightbox(index));
  });
  
  lightbox.addEventListener("click", (e) => {
    if (e.target === lightbox || e.target.classList.contains("close")) {
      closeLightbox();
    }
  });
  
  document.querySelector(".prev")?.addEventListener("click", (e) => {
    e.stopPropagation();
    changeImage(-1);
  });
  
  document.querySelector(".next")?.addEventListener("click", (e) => {
    e.stopPropagation();
    changeImage(1);
  });
});
