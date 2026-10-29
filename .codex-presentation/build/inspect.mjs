import fs from 'node:fs/promises';
import {FileBlob,PresentationFile} from '@oai/artifact-tool';
const p=await PresentationFile.importPptx(await FileBlob.load('docs/HUST_PPT_template_2022_RED_4x3.pptx'));
console.log((await p.inspect({kind:'layout',maxChars:8000})).ndjson);
console.log('masters',p.masters.items.map(m=>({id:m.id,name:m.name})));
for(const i of [2,3]){
 const s=p.slides.items[i];
 console.log('slide',i,s.id,s.frame);
 console.log('shapes',s.shapes.items.map(x=>({id:x.id,name:x.name,text:x.text.toString(),position:x.position,style:x.text.style})));
 console.log('ph',s.placeholders.items.map(x=>({name:x.name,text:x.text?.toString()})));
}
