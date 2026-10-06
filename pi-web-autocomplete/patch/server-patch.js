// pi-web 服务端补丁：支持扩展自动补全 provider
// 
// 用法：在 pi-web 启动前 require 此模块
//   node -r ./pi-web-autocomplete/patch/server-patch.js $(which pi-web)
//
// 原理：monkey-patch PiWebSession.createExtensionUiContext，
//       让 addAutocompleteProvider 实际存储 provider，
//       并新增 extension_ui_request 的 "autocomplete" 方法。

const fs = require('fs');
const path = require('path');

// pi-web 编译输出路径
const PI_WEB_DIST = path.join(
  process.env.PI_WEB_DIST || '',
  'node_modules', '@agegr', 'pi-web', '.next', 'server', 'chunks', '6429.js'
);

if (!fs.existsSync(PI_WEB_DIST)) {
  console.error('[pi-web-autocomplete] ERROR: Cannot find pi-web dist file:', PI_WEB_DIST);
  process.exit(1);
}

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
// 找到 extension_ui_request 的发送方法，在 requestExtensionUi 中
// 添加 autocomplete 方法支持
//
// 原始代码（简化）:
//   let j={type:"extension_ui_request",id:i,...a,...d?{timeout:d,expiresAt:Date.now()+d}:{}};
//
// 替换为:
//   let j={type:"extension_ui_request",id:i,...a,...d?{timeout:d,expiresAt:Date.now()+d}:{}};
//   if(j.method==="autocomplete"){
//     let p=autocompleteProviders[autocompleteProviders.length-1];
//     if(p){
//       p.getSuggestions([],0,0,{signal:new AbortController().signal})
//         .then(s=>{s?m({items:s.items,prefix:s.prefix}):m(null)})
//         .catch(()=>m(null));
//       return
//     }
//   }

const REQUEST_BUILD = 'let j={type:"extension_ui_request",id:i,...a,...d?{timeout:d,expiresAt:Date.now()+d}:{}};';
const REQUEST_WITH_AUTOCOMPLETE = `let j={type:"extension_ui_request",id:i,...a,...d?{timeout:d,expiresAt:Date.now()+d}:{}};
if(j.method==="autocomplete"){
  let p=autocompleteProviders[autocompleteProviders.length-1];
  if(p){
    p.getSuggestions([],0,0,{signal:new AbortController().signal,force:true})
      .then(s=>{if(s){m({items:s.items,prefix:s.prefix})}else{m(null)}})
      .catch(()=>m(null))
  }else{
    m(null)
  }
  return
}`;

if (patchedCode.includes(REQUEST_BUILD)) {
  patchedCode = patchedCode.replace(REQUEST_BUILD, REQUEST_WITH_AUTOCOMPLETE);
  console.log('[pi-web-autocomplete] ✓ Added autocomplete request handler');
} else {
  console.log('[pi-web-autocomplete] ⚠ request builder pattern not found');
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
