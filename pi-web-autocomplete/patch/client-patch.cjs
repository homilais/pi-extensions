// pi-web 客户端补丁：支持扩展自动补全弹窗
//
// 用法：node client-patch.cjs
//
// 原理：修改 pi-web 客户端代码，添加 get_autocomplete 请求支持
//
// 修改内容：
// 1. 添加 sendAutocompleteRequest 函数
// 2. 添加 autocomplete_result 消息监听
// 3. 修改 @-mention 检测，支持 @skill: 模式
// 4. 在弹窗中显示扩展建议

const fs = require('fs');
const path = require('path');

const PI_WEB_DIR = process.env.PI_WEB_DIST || 'C:\\ARayProgram\\nvm\\v22.20.0\\node_modules\\@agegr\\pi-web';
const CLIENT_FILE = path.join(PI_WEB_DIR, '.next', 'static', 'chunks', 'app', 'page-b5a19d562a153b66.js');

console.log('[pi-web-autocomplete] 客户端补丁');
console.log('[pi-web-autocomplete] 文件:', CLIENT_FILE);
console.log('');

if (!fs.existsSync(CLIENT_FILE)) {
  console.error('[pi-web-autocomplete] ERROR: 找不到客户端文件');
  console.error('[pi-web-autocomplete] 可能文件已被修改或版本不同');
  process.exit(1);
}

// 版本检查
try {
  const pkgPath = path.join(PI_WEB_DIR, 'package.json');
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
  if (pkg.version !== '0.9.3') {
    console.log(`[pi-web-autocomplete] ⚠ 警告: pi-web 版本 ${pkg.version} 未测试`);
    console.log('[pi-web-autocomplete]   客户端代码结构可能不同，请检查输出');
  }
} catch (e) {
  // 忽略
}

const originalCode = fs.readFileSync(CLIENT_FILE, 'utf-8');
let patchedCode = originalCode;
let patchCount = 0;

// === 补丁 1: 添加 sendAutocompleteRequest 函数 ===
//
// 在 function nu( 之前插入 sendAutocompleteRequest 函数
//
// 查找模式：nr(l)}function nu(
// 替换为：nr(l)}
// [pi-web-autocomplete] 扩展自动补全请求
// let piWebAutocompleteRequestIds=new Map();
// function sendAutocompleteRequest(prefix,trigger){...}
// function nu(

const INSERT_PATTERN_1 = 'nr(l)}function nu(';
const INSERT_REPLACEMENT_1 = `nr(l)}
// [pi-web-autocomplete] 扩展自动补全请求
let piWebAutocompleteRequestIds=new Map();
function sendAutocompleteRequest(prefix,trigger){
  let id=Date.now()+'-'+Math.random().toString(36).slice(2,8);
  let abortController=new AbortController();
  let timer=setTimeout(()=>{abortController.abort();piWebAutocompleteRequestIds.delete(id)},3000);
  piWebAutocompleteRequestIds.set(id,abortController);
  return fetch('/api/agent/current/messages',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({type:'get_autocomplete',requestId:id,prefix,trigger}),signal:abortController.signal})
  .then(r=>r.json())
  .then(data=>{clearTimeout(timer);piWebAutocompleteRequestIds.delete(id);return data})
  .catch(e=>{clearTimeout(timer);piWebAutocompleteRequestIds.delete(id);console.error('[pi-web-autocomplete] Error:',e.message);return{items:[],prefix:trigger}})
}
function nu(`;

if (patchedCode.includes(INSERT_PATTERN_1)) {
  patchedCode = patchedCode.replace(INSERT_PATTERN_1, INSERT_REPLACEMENT_1);
  patchCount++;
  console.log('[pi-web-autocomplete] ✓ 添加 sendAutocompleteRequest 函数');
} else {
  console.log('[pi-web-autocomplete] ⚠ 补丁 1 失败: 找不到插入点');
}

// === 补丁 2: 添加 autocomplete_result 消息监听 ===
//
// 查找 SSE 消息处理代码，添加 autocomplete_result 处理
//
// 查找模式：case"message_start" 或类似的消息处理

const SEARCH_PATTERN_2 = 'case"message_start"';
const AUTOCOMPLETE_HANDLER = `case"autocomplete_result":{if(data.requestId){let existing=piWebAutocompleteRequestIds.get(data.requestId);if(existing)existing.resolve?.(data)}break}case"message_start":`;

if (patchedCode.includes(SEARCH_PATTERN_2)) {
  patchedCode = patchedCode.replace(SEARCH_PATTERN_2, AUTOCOMPLETE_HANDLER);
  patchCount++;
  console.log('[pi-web-autocomplete] ✓ 添加 autocomplete_result 监听');
} else {
  console.log('[pi-web-autocomplete] ⚠ 补丁 2 失败: 找不到消息处理');
  // 尝试其他模式
  const altPattern = '"message_start"';
  let index = patchedCode.indexOf(altPattern);
  if (index !== -1) {
    console.log(`[pi-web-autocomplete] 找到替代模式 at pos ${index}`);
  }
}

// === 补丁 3: 修改 @-mention 检测，支持 @skill: ===
//
// 查找 nu 函数，添加 @skill: 检测
//
// 原始代码：
//   function nu(e){let t=/(?:^|\s)@"([^"\n]*)$/.exec(e);...}
//
// 修改为：
//   function nu(e){
//     // 先检测 @skill:
//     let skillMatch=/(?:^|\s)@skill:(\w*)$/.exec(e);
//     if(skillMatch){
//       sendAutocompleteRequest(skillMatch[1],'@skill:');
//       return{start:e.length-(skillMatch[1].length+8),query:skillMatch[1],quoted:!1,trigger:'@skill:'};
//     }
//     // 原有逻辑...
//     let t=/(?:^|\s)@"([^"\n]*)$/.exec(e);...}

const NU_FUNCTION_PATTERN = 'function nu(e){let t=/(?:^|\\s)@"([^"\\n]*)$/.exec(e);if(t)return{start:e.length-(t[1].length+2),query:t[1],quoted:!0};let n=/(?:^|\\s)@([^\\s"]*)$/.exec(e);return n?{start:e.length-(n[1].length+1),query:n[1],quoted:!1}:null}';

const NU_FUNCTION_PATCHED = `function nu(e){let skillMatch=/(?:^|\\s)@skill:(\\w*)$/.exec(e);if(skillMatch){sendAutocompleteRequest(skillMatch[1],'@skill:');return{start:e.length-(skillMatch[1].length+8),query:skillMatch[1],quoted:!1,trigger:'@skill:'}}let t=/(?:^|\\s)@"([^"\\n]*)$/.exec(e);if(t)return{start:e.length-(t[1].length+2),query:t[1],quoted:!0};let n=/(?:^|\\s)@([^\\s"]*)$/.exec(e);return n?{start:e.length-(n[1].length+1),query:n[1],quoted:!1}:null}`;

if (patchedCode.includes(NU_FUNCTION_PATTERN)) {
  patchedCode = patchedCode.replace(NU_FUNCTION_PATTERN, NU_FUNCTION_PATCHED);
  patchCount++;
  console.log('[pi-web-autocomplete] ✓ 修改 nu 函数，支持 @skill:');
} else {
  console.log('[pi-web-autocomplete] ⚠ 补丁 3 失败: nu 函数模式不匹配');
  // 尝试找到 nu 函数的实际模式
  let index = patchedCode.indexOf('function nu(');
  if (index !== -1) {
    let end = patchedCode.indexOf('}', index);
    let actualPattern = patchedCode.substring(index, end + 1);
    console.log(`[pi-web-autocomplete] 实际 nu 函数: ${actualPattern.substring(0, 200)}...`);
  }
}

// === 补丁 4: 在弹窗中显示扩展建议 ===
//
// 这个补丁比较复杂，需要修改弹窗渲染逻辑
// 先跳过，让用户知道需要手动完成

console.log('[pi-web-autocomplete] ⚠ 补丁 4 跳过: 弹窗渲染需要手动修改');
console.log('[pi-web-autocomplete]   参考 client-patch-guide.md');

// 写入修改后的文件
const backupPath = CLIENT_FILE + '.bak';
if (!fs.existsSync(backupPath)) {
  fs.copyFileSync(CLIENT_FILE, backupPath);
  console.log('[pi-web-autocomplete] ✓ 备份创建:', backupPath);
}

fs.writeFileSync(CLIENT_FILE, patchedCode, 'utf-8');
console.log('');
console.log('[pi-web-autocomplete] ✓ 客户端补丁应用完成');
console.log(`[pi-web-autocomplete] 成功: ${patchCount}/4`);
console.log('[pi-web-autocomplete] Run revert-patch.ps1 to restore original');
