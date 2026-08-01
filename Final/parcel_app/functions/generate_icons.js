const Jimp = require('jimp');
const fs = require('fs');
const path = require('path');

const basePath = '../';
const logoPath = path.join(basePath, 'assets', 'logo.png');

const sizes = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192
};

async function resizeImages() {
  try {
    const image = await Jimp.read(logoPath);
    for (const [key, size] of Object.entries(sizes)) {
      const resized = image.clone().resize(size, size);
      
      const outPath = path.join(basePath, 'android', 'app', 'src', 'main', 'res', `mipmap-${key}`, 'ic_launcher.png');
      await resized.writeAsync(outPath);
      
      const roundOutPath = path.join(basePath, 'android', 'app', 'src', 'main', 'res', `mipmap-${key}`, 'ic_launcher_round.png');
      if (fs.existsSync(roundOutPath)) {
        await resized.writeAsync(roundOutPath);
      }
      
      console.log(`Generated icon for mipmap-${key}`);
    }
  } catch (err) {
    console.error(err);
  }
}

resizeImages();
