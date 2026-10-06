// pi-web 服务端补丁：支持扩展自动补全 provider
// 
// 用法：node -e "process.env.PI_WEB_DIST='...'; require('./server-patch.cjs')"
// 或：  PI_WEB_DIST=/path/to/pi-web node server-patch.cjs
//
// 原理：monkey-patch PiWebSession.createExtensionUiContext，
//       让 addAutocompleteProvider 实际存储 provider，
//       并新增 extension_ui_request 的 "autocomplete" 方法。
//
// 版本兼容性：
// - 适用于 pi-web 0.9.3
// - 其他版本需手动验证字符串模式
// - 建议检查 package.json 中的 pi-web 版本

const fs = require('fs');
const path = require('path');

// === 版本检查 ===
const SUPPORTED_VERSIONS = ['0.9.3'];

function getPiWebVersion() {
  try {
    // 从 PI_WEB_DIST 提取 pi-web 基础目录
    const distFile = path.basename(PI_WEB_DIST);
    const distDir = path.dirname(PI_WEB_DIST);
    // 向上找到 package.json
    let dir = distDir;
    for (let i = 0; i < 5; i++) {
      const pkgPath = path.join(dir, 'package.json');
      if (fs.existsSync(pkgPath)) {
        const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
        if (pkg.name === '@agegr/pi-web') {
          return pkg.version;
        }
      }
      dir = path.dirname(dir);
    }
    return null;
  } catch (e) {
    return null;
  }
}

function checkVersion(version) {
  if (!version) {
    console.log('[pi-web-autocomplete] ⚠ 无法读取 pi-web 版本，继续执行...');
    return true;
  }
  if (!SUPPORTED_VERSIONS.includes(version)) {
    console.log(`[pi-web-autocomplete] ⚠ 警告: pi-web 版本 ${version} 未测试`);
    console.log(`[pi-web-autocomplete]   支持版本: ${SUPPORTED_VERSIONS.join(', ')}`);
    console.log('[pi-web-autocomplete]   字符串模式可能不匹配，请检查输出');
    return true; // 继续执行，让用户决定
  }
  return true;
}

// pi-web 编译输出路径
// 如果设置了 PI_WEB_DIST 环境变量，直接使用（包含 pi-web 目录）
// 否则尝试常见路径
const PI_WEB_DIST_PATH = process.env.PI_WEB_DIST || '';

let PI_WEB_DIST;
if (PI_WEB_DIST_PATH) {
  // 使用环境变量指定的路径
  PI_WEB_DIST = path.join(PI_WEB_DIST_PATH, '.next', 'server', 'chunks', '6429.js');
} else {
  // 尝试常见安装路径
  const candidates = [
    path.join(process.env.APPDATA || '', 'npm', 'node_modules', '@agegr', 'pi-web', '.next', 'server', 'chunks', '6429.js'),
    path.join(process.env.HOME || '', '.npm-global', 'lib', 'node_modules', '@agegr', 'pi-web', '.next', 'server', 'chunks', '6429.js'),
    path.join(process.env.HOME || '', '.local', 'share', 'pi-web', '.next', 'server', 'chunks', '6429.js'),
  ];
  PI_WEB_DIST = candidates.find(p => fs.existsSync(p));
  if (!PI_WEB_DIST) {
    console.error('[pi-web-autocomplete] ERROR: Cannot find pi-web dist file');
    console.error('[pi-web-autocomplete] Set PI_WEB_DIST environment variable, e.g.:');
    console.error('  PI_WEB_DIST=$(npm root -g)/@agegr/pi-web');
    process.exit(1);
  }
}

if (!fs.existsSync(PI_WEB_DIST)) {
  console.error('[pi-web-autocomplete] ERROR: Cannot find pi-web dist file:', PI_WEB_DIST);
  process.exit(1);
}

// 版本检查
const version = getPiWebVersion();
console.log(`[pi-web-autocomplete] pi-web 版本: ${version || '未知'}`);
checkVersion(version);

const originalCode = fs.readFileSync(PI_WEB_DIST, 'utf-8');
let patchedCode = originalCode;

// === 补丁 1: 添加 autocompleteProviders 存储 ===
// 在 createExtensionUiContext 方法之前注入 provider 存储
// 
// 原始代码（minified）:
//   createExtensionUiContext(){return{
// 
// 替换为:
//   autocompleteProviders:[],createExtensionUiContext(){return{

const ADD_STORAGE = 'createExtensionUiContext(){return{';
const WITH_STORAGE = 'autocompleteProviders:[],createExtensionUiContext(){return{';

if (patchedCode.includes(ADD_STORAGE)) {
  patchedCode = patchedCode.replace(ADD_STORAGE, WITH_STORAGE);
  console.log('[pi-web-autocomplete] ✓ Added autocompleteProviders storage');
} else {
  console.log('[pi-web-autocomplete] ⚠ addAutocompleteProvider storage pattern not found');
}

// === 补丁 2: 替换 addAutocompleteProvider no-op ===
//
// 原始代码:
//   addAutocompleteProvider:()=>{}
// 
// 替换为:
//   addAutocompleteProvider:(factory)=>{
//     let p=factory();
//     autocompleteProviders.push(p);
//     return p
//   }

const ADD_PROVIDER_NOOP = 'addAutocompleteProvider:()=>{}';
const ADD_PROVIDER_IMPL = `addAutocompleteProvider:(factory)=>{
  try{
    let current=autocompleteProviders.length>0?autocompleteProviders[autocompleteProviders.length-1]:null;
    let next=current?factory(current):factory();
    autocompleteProviders.push(next);
    return next
  }catch(e){
    console.error('[pi-web-autocomplete] addAutocompleteProvider error:',e.message)
  }
}`;

if (patchedCode.includes(ADD_PROVIDER_NOOP)) {
  patchedCode = patchedCode.replace(ADD_PROVIDER_NOOP, ADD_PROVIDER_IMPL);
  console.log('[pi-web-autocomplete] ✓ Patched addAutocompleteProvider');
} else {
  console.log('[pi-web-autocomplete] ⚠ addAutocompleteProvider no-op pattern not found');
}

// === 补丁 3: 新增 autocomplete 请求处理 ===
//
// 找到 resolveExtensionUiResponse 方法，在其后添加 handleAutocompleteRequest 方法
// 然后在 send 方法的 switch 中添加 case"get_autocomplete"
//
// 原始代码（resolveExtensionUiResponse 方法结束）:
//   resolveExtensionUiResponse(a){let b=this.pendingUiResponses.get(a.id);b&&b.resolve(a)}
//
// 替换为:
//   resolveExtensionUiResponse(a){let b=this.pendingUiResponses.get(a.id);b&&b.resolve(a)}
//   handleAutocompleteRequest(a){
//     let p=autocompleteProviders[autocompleteProviders.length-1];
//     if(!p){this.emit({type:"autocomplete_result",requestId:a.requestId,items:[]});return null}
//     p.getSuggestions([],0,0,{signal:new AbortController().signal,force:true})
//       .then(s=>{let items=s?s.items:[];this.emit({type:"autocomplete_result",requestId:a.requestId,items,prefix:s?s.prefix:a.trigger})})
//       .catch(()=>this.emit({type:"autocomplete_result",requestId:a.requestId,items:[]}))
//     return null
//   }

const METHOD_END = 'resolveExtensionUiResponse(a){let b=this.pendingUiResponses.get(a.id);b&&b.resolve(a)}';
const METHOD_WITH_AUTOCOMPLETE = `resolveExtensionUiResponse(a){let b=this.pendingUiResponses.get(a.id);b&&b.resolve(a)}handleAutocompleteRequest(a){let p=autocompleteProviders[autocompleteProviders.length-1];if(!p){this.emit({type:"autocomplete_result",requestId:a.requestId,items:[]});return null}p.getSuggestions([],0,0,{signal:new AbortController().signal,force:true}).then(s=>{let items=s?s.items:[];this.emit({type:"autocomplete_result",requestId:a.requestId,items,prefix:s?s.prefix:a.trigger})}).catch(()=>this.emit({type:"autocomplete_result",requestId:a.requestId,items:[]}))return null}`;

if (patchedCode.includes(METHOD_END)) {
  patchedCode = patchedCode.replace(METHOD_END, METHOD_WITH_AUTOCOMPLETE);
  console.log('[pi-web-autocomplete] ✓ Added handleAutocompleteRequest method');
} else {
  console.log('[pi-web-autocomplete] ⚠ resolveExtensionUiResponse method pattern not found');
}

// === 补丁 4: 在 send 方法中添加 case ===
//
// 找到 case"extension_ui_input"，在其后添加 case"get_autocomplete"
//
// 原始代码:
//   case"extension_ui_input":return this.handleExtensionUiInput(a.id,a.data),null;
//
// 替换为:
//   case"extension_ui_input":return this.handleExtensionUiInput(a.id,a.data),null;
//   case"get_autocomplete":return this.handleAutocompleteRequest(a),null;

const CASE_INPUT = 'case"extension_ui_input":return this.handleExtensionUiInput(a.id,a.data),null;';
const CASE_WITH_AUTOCOMPLETE = 'case"extension_ui_input":return this.handleExtensionUiInput(a.id,a.data),null;case"get_autocomplete":return this.handleAutocompleteRequest(a),null;';

if (patchedCode.includes(CASE_INPUT)) {
  patchedCode = patchedCode.replace(CASE_INPUT, CASE_WITH_AUTOCOMPLETE);
  console.log('[pi-web-autocomplete] ✓ Added get_autocomplete case');
} else {
  console.log('[pi-web-autocomplete] ⚠ extension_ui_input case pattern not found');
}

// 写入修改后的文件
const backupPath = PI_WEB_DIST + '.bak';
if (!fs.existsSync(backupPath)) {
  fs.copyFileSync(PI_WEB_DIST, backupPath);
  console.log('[pi-web-autocomplete] ✓ Backup created:', backupPath);
}

fs.writeFileSync(PI_WEB_DIST, patchedCode, 'utf-8');
console.log('[pi-web-autocomplete] ✓ Server patch applied to:', PI_WEB_DIST);
console.log('[pi-web-autocomplete] Run revert-patch.ps1 to restore original');
