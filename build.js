const luabundle = require('luabundle');
const fs = require('fs');
const path = require('path');

const outDir = 'build';
const outFile = path.join(outDir, 'smsmenu.lua');
const srcFile = path.join('src', 'smsmenu.lua');

if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
}

// These are libraries we DO NOT want to bundle (they are resolved by moonloader at runtime)
const ignoredModules = [
    'lib.moonloader',
    'lib.mimgui',
    'ffi',
    'lib.dkjson',
    'lfs',
    'lib.samp.events',
    'encoding'
];

const options = {
    luaVersion: 'LuaJIT',
    isolate: false, // Allows require() fallback at runtime
    paths: [
        '?.lua',
        '?/init.lua',
        'src/?.lua',
        'src/?/init.lua'
    ],
    ignoredModuleNames: ignoredModules,
    resolveModule: function (name, packagePaths) {
        if (ignoredModules.includes(name)) return null;
        const platformName = name.replace(/\./g, path.sep);
        for (const pattern of packagePaths) {
            const p = pattern.replace(/\?/g, platformName);
            if (fs.existsSync(p) && fs.lstatSync(p).isFile()) {
                return p;
            }
        }
        return null;
    }
};

try {
    const bundledContent = luabundle.bundle(srcFile, options);
    fs.writeFileSync(outFile, bundledContent, 'utf-8');
    console.log(`Successfully bundled to ${outFile}`);
} catch (error) {
    console.error(`Bundling failed: ${error.message}`);
    process.exit(1);
}
