// Browser-independent interaction/data-shape harness. This does not verify WebGL.
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert');
const out=path.join(__dirname,'results/kwave_widegrid_2026-10-24/interactive');
const html=fs.readFileSync(path.join(out,'widefield_pressure_3d.html'),'utf8');
const runtime=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1];
function element(value='',checked=false,dataset={}){return {value,checked,dataset,disabled:true,hidden:false,textContent:'',innerHTML:'',max:1,listeners:{},addEventListener(name,fn){this.listeners[name]=fn}}}
const el={caseSelect:element('0'),scaleSelect:element('pa'),depth:element('0'),planeToggle:element('',false)};
const isos=[0,1,2].map(i=>element('',true,{iso:String(i)}));
const presets=['shallow','deep','target'].map(depth=>element('',false,{depth}));
const graphs={}, errors=[],calls=[];
const document={querySelector(selector){const m=selector.match(/^\[data-iso="(\d)"\]$/);if(m)return isos[+m[1]];const id=selector.slice(1);return el[id]||(el[id]=element())},querySelectorAll(selector){return selector==='[data-iso]'?isos:selector==='[data-depth]'?presets:[]}};
const plotly={async react(id,traces,layout){for(const t of traces){if(t.type==='heatmap'){assert.equal(t.z.length,t.y.length,'heatmap rows/y');assert.equal(t.z[0].length,t.x.length,'heatmap columns/x')}if(t.type==='surface'){assert.equal(t.z.length,t.y.length);assert.equal(t.z[0].length,t.x.length)}}graphs[id]={data:traces,layout};calls.push('react:'+id)},async restyle(id,update,indices){calls.push('restyle:'+id);for(const i of indices)for(const [key,value] of Object.entries(update))graphs[id].data[i][key]=Array.isArray(value)?value[0]:value},async relayout(id,update){calls.push('relayout:'+id);Object.assign(graphs[id].layout,update)}};
const sandbox={document,window:{},Plotly:plotly,console:{error:e=>errors.push(String(e))},Uint8Array,Blob,DecompressionStream,Response,atob};
sandbox.window=sandbox;
vm.createContext(sandbox);vm.runInContext(runtime,sandbox);
(async()=>{
  for(let i=0;i<400&&!sandbox.window.viewerReady&&!errors.length;i++)await new Promise(r=>setTimeout(r,25));
  assert.equal(errors.length,0,errors.join('\n'));assert(sandbox.window.viewerReady,'runtime init');assert.equal(Object.keys(graphs).length,4);
  assert.equal(+el.depthValue.textContent,2.028,'default shallow slice');
  const thresholds=graphs.volume.data.slice(0,3).map(m=>m.name);
  el.caseSelect.value='1';el.caseSelect.listeners.change();await vm.runInContext('renderQueue',sandbox);
  assert.equal(vm.runInContext('selected',sandbox),1);assert.deepEqual(graphs.volume.data.slice(0,3).map(m=>m.name),thresholds);
  presets[1].listeners.click();await vm.runInContext('renderQueue',sandbox);assert.equal(+el.depthValue.textContent,18.46);
  presets[2].listeners.click();await vm.runInContext('renderQueue',sandbox);assert.equal(+el.depthValue.textContent,20.02);
  el.planeToggle.checked=true;el.planeToggle.listeners.change({target:el.planeToggle});await vm.runInContext('renderQueue',sandbox);assert.equal(graphs.volume.data.at(-1).visible,true);
  isos[0].checked=false;isos[0].listeners.change();await vm.runInContext('renderQueue',sandbox);assert.equal(graphs.volume.data[0].visible,false);
  el.scaleSelect.value='db';el.scaleSelect.listeners.change();await vm.runInContext('renderQueue',sandbox);assert.equal(graphs.xz.data[0].zmin,-40);assert(graphs.xz.data[0].zmax>6);
  el.shallowCamera.onclick();await vm.runInContext('renderQueue',sandbox);assert.deepEqual(Array.from(graphs.volume.layout['scene.zaxis.range']),[5,0]);
  el.focusCamera.onclick();await vm.runInContext('renderQueue',sandbox);assert.deepEqual(Array.from(graphs.volume.layout['scene.zaxis.range']),[25,12]);
  el.resetCamera.onclick();await vm.runInContext('renderQueue',sandbox);assert(graphs.volume.layout['scene.zaxis.range'][0]>30);
  el.caseSelect.value='0';el.caseSelect.listeners.change();await vm.runInContext('renderQueue',sandbox);presets[0].listeners.click();await vm.runInContext('renderQueue',sandbox);assert.equal(+el.depthValue.textContent,2.028);
  assert.equal(errors.length,0);
  const result={init:true,graphs:4,checks:11,case_switch:true,shared_scale:true,depth_presets:true,plane_toggle:true,surface_toggle:true,db_scale:true,camera_presets:true,heatmap_shapes:true,errors,webgl_rendering:'not tested; DOM and Plotly stubs only'};
  fs.writeFileSync(path.join(out,'runtime_logic_validation.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
})().catch(e=>{console.error(e);process.exitCode=1});
