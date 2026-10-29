import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {FileBlob, PresentationFile} from '@oai/artifact-tool';
import sharp from 'sharp';
import {finalizePresentation} from '/Users/fuzzefer/.codex/plugins/cache/openai-primary-runtime/presentations/26.1015.12040/skills/presentations/container_tools/artifact_tool_utils.mjs';

const ROOT='/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO';
const BUILD=path.join(ROOT,'.codex-presentation');
const SKILL='/Users/fuzzefer/.codex/plugins/cache/openai-primary-runtime/presentations/26.1015.12040/skills/presentations';
const PYTHON='/Users/fuzzefer/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3';
const SOURCE=path.join(ROOT,'docs/HUST_PPT_template_2022_RED_4x3.pptx');
const CANDIDATE=path.join(BUILD,'draft.pptx');
const FINAL=path.join(ROOT,'output/HUST_Alpha_L.pptx');
const red='#C00000', ink='#222222', gray='#555555';
const p=await PresentationFile.importPptx(await FileBlob.load(SOURCE));
const cover=p.slides.items[2], base=p.slides.items[3];
const bodies=[base];
for(let i=0;i<6;i++)bodies.push(base.duplicate());
const chosen=[cover,...bodies];
p.slides.keep(chosen.map(s=>'sl/'+s.id));
p.slides.reorder(chosen.map(s=>'sl/'+s.id));

function text(slide,name,value,x,y,w,h,size=24,opts={}){
 const s=slide.shapes.add({geometry:'textbox',name,position:{left:x,top:y,width:w,height:h},fill:'none',line:{fill:'none',width:0}});
 s.text=value;
 s.text.style={typeface:'Lato',fontSize:size,color:ink,verticalAlignment:'top',alignment:'left',autoFit:'none',wrap:'square',insets:0,...opts};
 return s;
}
function notes(slide,value){slide.speakerNotes.text=value;}
async function math(slide,name,x,y,w,h){
 const buffer=await fs.readFile(path.join(BUILD,'assets/math',name+'.png'));
 const meta=await sharp(buffer).metadata();
 const scale=Math.min(w/meta.width,h/meta.height),iw=meta.width*scale,ih=meta.height*scale;
 return slide.images.add({name:'formula_'+name,blob:buffer.buffer.slice(buffer.byteOffset,buffer.byteOffset+buffer.byteLength),contentType:'image/png',alt:'Công thức '+name,fit:'contain',position:{left:x,top:y+(h-ih)/2,width:iw,height:ih}});
}
function body(slide,title,index){
 for(const sh of [...slide.shapes.items]){
  if(sh.name.includes('Slide Number')){sh.text=String(index);sh.text.style={typeface:'Lato',fontSize:14,color:red,alignment:'right',insets:0};}
  else if(sh.name.startsWith('Title')){
   sh.text=title;
   sh.position={left:28,top:9,width:900,height:52};
   sh.text.style={typeface:'Lato',fontSize:36,bold:true,color:'#FFFFFF',insets:0,verticalAlignment:'middle',autoFit:'none'};
  } else {sh.text='';}
 }
}
function table(slide,name,values,y=160,height=350){
 const t=slide.tables.add({rows:values.length,columns:values[0].length,left:56,top:y,width:848,height,columnWidths:[158,230,230,230],values});
 t.name=name;
 t.borders.assign({style:'solid',fill:'#D8D8D8',width:0.6});
 for(let r=0;r<values.length;r++)for(let c=0;c<values[r].length;c++){
  const cell=t.getCell(r,c);
  cell.fill=r===0?red:(r%2?'#FFFFFF':'#F8F3F3');
  cell.text.style={typeface:'Lato',fontSize:r===0?23:25,bold:r===0,color:r===0?'#FFFFFF':ink,alignment:'center',verticalAlignment:'middle',insets:6,wrap:'square',autoFit:'none'};
 }
 return t;
}
const title=cover.shapes.items[0], subtitle=cover.shapes.items[1];
title.text='HỆ SỐ α VÀ\nRÀNG BUỘC DỮ LIỆU L';
title.position={left:43,top:252,width:745,height:145};
title.text.style={typeface:'Lato',fontSize:47,bold:true,color:red,insets:0,autoFit:'none',wrap:'square'};
subtitle.text='Phân tích EE RF trong hệ UAV–SWIPT–NOMA';
subtitle.position={left:43,top:412,width:680,height:92};
subtitle.text.style={typeface:'Lato',fontSize:27,color:red,insets:0,autoFit:'none',wrap:'square'};
notes(cover,'Phạm vi: giải thích cấu trúc nghiệm alpha đều của V9 EE RF trước ràng buộc dữ liệu, sau đó tổng hợp sáu lần chạy có L. Template gốc: docs/HUST_PPT_template_2022_RED_4x3.pptx. Các mô phỏng do người dùng đã chạy. Không tái chạy MATLAB.');

// 2. Context and exact objective.
let s=bodies[0];body(s,'Bối cảnh bài toán EE RF',2);
text(s,'scenario','5 user, 3 BS, 20 slot trong 20 giây\nMỗi slot gồm 0,5 s UL và 0,5 s DL',56,103,848,75,29,{bold:true});
text(s,'metric-label','TỔNG DỮ LIỆU VÀ NĂNG LƯỢNG RF',56,207,848,32,21,{color:red,bold:true});
await math(s,'bits_energy',56,246,830,70);
await math(s,'ee',56,322,830,110);
text(s,'algorithms','Joint PSO: tối ưu quỹ đạo và α, giữ BS cố định\nFull PSO / Full IPSO: tối ưu thêm vị trí BS',56,445,848,77,25);
text(s,'initial-problem','Khi L = 0, mục tiêu chỉ xét tổng bit trên năng lượng RF.\nChưa yêu cầu mỗi user phải nhận đủ một lượng dữ liệu.',56,553,848,68,24,{color:red});
text(s,'energy-scope','Chỉ tính RF phát xuống của UAV, chưa gồm năng lượng bay và mạch.',56,632,848,27,18,{color:gray});
notes(s,'Nguồn: scripts/maincodeV9_EE.m, src/evaluators/addRFSlotMetrics.m, docs/EE_RESEARCH_CONTEXT.md mục 10–16. n=1..20, k=1..5. τDL=0.5 s. Mẫu số chỉ gồm năng lượng RF phát xuống của UAV, chưa gồm năng lượng bay, mạch hoặc năng lượng BS. Kênh lấy tại đầu slot và giả định UL đủ dữ liệu. Endpoint 21 là điểm đến, không tạo thêm slot. Chỉ thời gian DL triệt tiêu trong tỷ số, P vẫn nằm trong SINR nên không triệt tiêu khỏi EE. Các số seed3486784401 ở phần bảng là các lần chạy riêng so với ảnh L=0.');

// 3. Physical model and SIC/order constraints.
s=bodies[1];body(s,'Công thức SWIPT và NOMA',3);
text(s,'eh-label','CÔNG SUẤT UAV TỪ NĂNG LƯỢNG THU HOẠCH',56,101,848,32,21,{color:red,bold:true});
await math(s,'power',56,151,820,50);
text(s,'power-params','Hₙ: tổng độ lợi kênh 3 BS.  φ = η = 0,9.  P_BS = 46 dBm.',56,212,848,37,23);
text(s,'noma-label','THỨ TỰ KÊNH YẾU ĐẾN MẠNH TRONG MỖI SLOT',56,253,848,32,21,{color:red,bold:true});
await math(s,'ordering',56,291,810,61);
await math(s,'interference',56,354,500,56);
await math(s,'sinr',56,410,690,108);
await math(s,'rate',56,532,745,45);
text(s,'definitions','gₙᵢ là độ lợi kênh UAV–user. σ² là công suất nhiễu.\nSIC lý tưởng khử các tín hiệu của user yếu hơn.',56,590,848,63,23,{color:gray});
notes(s,'Nguồn: src/models/findAchievableRate_SWIPT_Joint.m và phần repair trong src/evaluators/evaluateTrajectory_JointSWIPT_clean.m, src/evaluators/evaluateTrajectory_JointBS_SWIPT_clean.m. Mỗi slot xếp g=|h|² tăng dần. Repair jointAlphaRepair="noma" sắp alpha giảm dần theo thứ tự kênh, tổng alpha bằng 1, alpha dương. Chỉ số i là hạng kênh, không phải ID user vật lý. h_bn là kênh BS b đến UAV. E_H=φη P_BS Σ|h_bn|² τUL; Pn=E_H/τDL. Hàm rate giữ tỷ số thời gian UL/DL bằng 1. Model hardcode B=1e6, noise density=-174 dBm/Hz. Công suất BS 46 dBm là mỗi BS, phải đổi sang W khi tính công thức.');

// 4. Exact mechanism, no low-SNR approximation.
s=bodies[2];body(s,'Vì sao α tối ưu bằng 0,2 khi L = 0?',4);
text(s,'fixed-geometry','Giữ quỹ đạo và BS cố định: P không phụ thuộc α.\nTối đa EE theo α tương đương tối đa tổng rate.',56,99,848,72,26,{bold:true});
text(s,'tail-label','Xét một slot, đặt',56,193,232,42,25);
await math(s,'tail',300,183,530,63);
await math(s,'sum_rate',56,252,840,90);
text(s,'derivative-label','Mỗi hạng fᵢ tăng theo Sᵢ vì',56,356,848,38,23);
await math(s,'derivative',56,390,820,85);
text(s,'tail-bound','Ordering cho Sᵢ ≤ (6 − i)/5. αᵢ = 1/5 đạt mọi cận.',56,485,848,42,25);
text(s,'conclusion','αᵢ = 0,2 tối đa tổng rate và EE RF\ntại cùng quỹ đạo, BS',56,536,848,78,30,{bold:true,color:red});
text(s,'polish','Polishing luôn thử α đều tại mỗi slot, giúp hai bản Full nhận nghiệm này.',56,623,848,34,20,{color:gray});
notes(s,'Nguồn và chứng minh: docs/EE_RF_DIAGNOSIS_SEED2026.md mục 2–3, docs/EE_RESEARCH_CONTEXT.md mục 12 và 16. Biểu thức đúng với mọi P>0, noise>0, không dùng xấp xỉ low-SNR. α giảm dần và tổng 1 nên tail S_i không vượt (N-i+1)/N. Chia đều đạt mọi cận của tail đồng thời, vì vậy tối ưu sum-rate ở từng slot và EE của toàn mission khi hình học cố định. Nếu kênh bằng nhau có thể có nhiều nghiệm đồng tối ưu, không khẳng định duy nhất. Đây là hệ quả của mục tiêu sum-rate/EE cùng ordering hiện hành, không phải kết luận cho mọi bài toán NOMA hoặc mục tiêu min-rate V8. Phạm vi slide là L=0. polishAlphaAllSteps_JointBS.m thử equal alpha đầu tiên và chỉ nhận candidate tăng fitness toàn mission. Main chỉ polish Full PSO và Full IPSO, không polish Joint PSO.');

// 5. User-provided original evidence.
s=bodies[3];body(s,'Đồ thị α trước khi thêm L',5);
const img=await fs.readFile(path.join(BUILD,'assets/supplied_results.png'));
s.images.add({name:'alpha_L0_original',blob:img.buffer.slice(img.byteOffset,img.byteOffset+img.byteLength),contentType:'image/png',alt:'Đồ thị người dùng cung cấp: mean NOMA alpha của 5 user theo iteration cho Joint PSO, Full PSO và Full IPSO, L=0.',fit:'contain',position:{left:92,top:94,width:776,height:506}});
text(s,'figure-caption','L = 0: hai bản Full đạt gần 0,2 sau polishing. Joint PSO còn lệch.\nHình thể hiện α trung bình theo slot của từng user.',56,609,848,42,18,{color:gray});
notes(s,'Ảnh gốc người dùng cung cấp: image(20261021-181045).png, Library ID libfile_54125c17df7c81918a62f45aba0a885d, file_00000000cea0820784f407c44a4654af. Người dùng xác nhận trong câu hỏi làm rõ: ảnh thuộc trường hợp chưa thêm L, tức L=0. Không gán seed3486784401 cho ảnh vì chưa có xác nhận. Đường gạch là 1/N=0.2. Mỗi đường là trung bình alpha qua các slot cho ID user vật lý. Hai bản Full có điểm sau polishing ở khoảng 0.2; Joint còn lệch ở vòng cuối. Ảnh trung bình không đủ để xác nhận mọi slot có alpha=0.2. Chẩn đoán riêng seed608060 trong docs/EE_RESEARCH_CONTEXT.md mục 12 xác nhận max|alpha-0.2|=0 cho Full PSO/IPSO, Joint=0.2975822, nhưng không khẳng định ảnh này thuộc seed đó.');

// 6. Minimum mission data QoS.
s=bodies[4];body(s,'Thêm giới hạn dữ liệu L bit/user',6);
await math(s,'data_constraint',56,107,595,71);
text(s,'constraint-users','với mọi user k',676,127,230,39,25,{color:red});
text(s,'meaning','L là tổng dữ liệu tối thiểu mỗi user nhận trong cả chuyến bay.\nCác mức thử: 1 / 1,5 / 2 / 3 / 4 / 4,2 Mbit/user.',56,187,848,78,25);
text(s,'fitness-label','CÁCH XẾP HẠNG NGHIỆM TRONG CODE',56,298,848,32,21,{bold:true,color:red});
text(s,'fitness-feasible','Đạt mọi ràng buộc:     fitness = EE_RF',56,344,848,40,27,{bold:true});
text(s,'fitness-infeasible-label','Thiếu dữ liệu:',56,422,226,40,25);
await math(s,'penalty',298,401,559,77);
text(s,'alpha-after-qos','Nếu α đều vẫn đáp ứng L, nghiệm đều vẫn tối ưu theo α\ntại cùng hình học. Khi ràng buộc dữ liệu loại nghiệm đều,\nbài toán có thể cần đổi α hoặc quỹ đạo, BS.',56,496,848,107,25);
text(s,'units','Điểm phạt âm xếp hạng phần thiếu dữ liệu. Đây không phải giá trị EE.',56,625,848,30,18,{color:gray});
notes(s,'Nguồn: src/evaluators/addRFSlotMetrics.m. D_k tính theo ID user vật lý, cộng 20 slot với τDL=0.5 s. L scalar áp dụng cho mọi user, 0 tắt yêu cầu; code cũng hỗ trợ vector L_k. Với particle vi phạm ràng buộc hình học hoặc EE undefined, fitness=-Inf. Công thức penalty hiển thị chỉ áp dụng khi hình học và năng lượng hợp lệ nhưng dataQoSFeasible=false. Feasible EE>=0 luôn thắng normalized shortfall âm. Với L>0, chứng minh uniform tối ưu của bài toán không QoS chỉ còn áp dụng nếu uniform tại hình học xét vẫn đáp ứng QoS. L không tự động bảo đảm alpha khác đều và một uniform không đạt tại một hình học không chứng minh mọi uniform trên toàn miền đều không đạt. Dấu ≥ là yêu cầu tối thiểu, không phải giới hạn trên tổng dữ liệu.');

// Parse exact published console metrics. The logs are the source of numerical tables.
const manifest=JSON.parse(await fs.readFile(path.join(ROOT,'results/ee_rf/logs/manifest.json'),'utf8'));
const names=['Joint PSO','Full PSO','Full IPSO'];
const results=[];
for(const run of manifest.runs){
 const raw=await fs.readFile(path.join(ROOT,'results/ee_rf/logs',run.file),'utf8');
 if(createHash('sha256').update(raw).digest('hex')!==run.sha256)throw Error('Source log checksum mismatch '+run.file);
 const metrics=[];
 for(const name of names){
  const escaped=name.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
  const rx=new RegExp(escaped+'\\s+\\| totalBits ([\\deE+.-]+) bit \\| totalEnergy ([\\deE+.-]+) J \\| EE ([\\deE+.-]+) bit/J \\| feasible ([01])\\s+totalBitsPerUser \\(bit\\):\\s+1\\.0e\\+([0-9]+) \\*\\s+([\\s\\S]*?)\\s+bitsShortfallPerUser');
  const m=raw.match(rx);if(!m)throw Error('Missing final metrics '+run.file+' '+name);
  const bitValues=m[6].trim().split(/\s+/).map(Number).map(x=>x*10**Number(m[5]));
  if(bitValues.length!==5)throw Error('Expected 5 users');
  metrics.push({name,bits:Number(m[1]),energy:Number(m[2]),ee:Number(m[3]),feasible:m[4]==='1',bitsPerUser:bitValues,minBits:Math.min(...bitValues)});
 }
 results.push({L:run.min_bits_per_user/1e6,file:run.file,metrics});
}
await fs.writeFile(path.join(BUILD,'run_metrics.json'),JSON.stringify(results,null,2));
const f=(v,d)=>v.toFixed(d).replace('.',',');

// 7. EE summary, explicitly distinguish infeasible diagnostics.
s=bodies[5];body(s,'Kết quả theo L: hiệu quả năng lượng',7);
text(s,'ee-units','EE_RF, đơn vị 10¹² bit/J. Seed 3486784401.',56,106,848,38,25);
const eeRows=[['L\n(Mbit/user)','Joint PSO','Full PSO','Full IPSO'],...results.map(r=>[f(r.L,r.L%1?1:0),...r.metrics.map(m=>f(m.ee/1e12,3)+(m.feasible?'':' *'))])];
const eeTable=table(s,'EE_summary',eeRows,166,360);
for(let r=0;r<results.length;r++){
 const row=results[r];
 const best=Math.max(...row.metrics.filter(m=>m.feasible).map(m=>m.ee));
 for(let c=0;c<3;c++){
  const cell=eeTable.getCell(r+1,c+1);
  if(!row.metrics[c].feasible){cell.text.style={typeface:'Lato',fontSize:25,color:'#888888',alignment:'center',verticalAlignment:'middle'};}
  else if(row.metrics[c].ee===best){cell.text.style={typeface:'Lato',fontSize:25,color:red,bold:true,alignment:'center',verticalAlignment:'middle'};}
 }
}
text(s,'ee-legend','* Chưa đạt L. EE của nghiệm này chỉ dùng để chẩn đoán.\nSố đỏ: EE cao nhất trong các nghiệm đạt yêu cầu ở cùng mức L.',56,551,848,60,21,{color:gray});
text(s,'ee-finding','Full IPSO có EE cao nhất ở 5/6 mức L đã thử.',56,625,848,30,22,{color:red,bold:true});
notes(s,'Nguồn số liệu: results/ee_rf/logs/manifest.json và sáu file seed3486784401_L1Mbit.log, L1p5Mbit.log, L2Mbit.log, L3Mbit.log, L4Mbit.log, L4p2Mbit.log. Các log là bản console người dùng cung cấp, nhãn L từ manifest/các trao đổi gốc, log không trực tiếp in L. EE lấy từ phần RF EE sau FINAL RESULT, dùng eeRF dù particle infeasible. Với Joint tại L>=3, fitness thực tế âm theo shortfall, không lấy EE này làm nghiệm khả thi. Full PSO/IPSO là kết quả sau alpha polishing. Làm tròn EE tới 3 chữ số sau dấu phẩy theo đơn vị 1e12 bit/J. Số đỏ là lớn nhất trong ba nghiệm cuối đã tìm được và đạt QoS, không phải khẳng định tối ưu toàn cục. Baseline giữ nguyên 7.214029 Mbit, 1.551204 microjoule, EE=4.650600e12 bit/J và không đạt cả sáu mức L, nên không lặp lại thành cột trong bảng. L=1 Mbit in đủ kết quả cuối trước lỗi plotting, nên vẫn dùng số metrics cuối, không suy dựng đồ thị iteration cho lượt đó.');

// 8. Minimum user delivery and honest alpha evidence annotation.
s=bodies[6];body(s,'Mức dữ liệu tối thiểu và trạng thái α',8);
text(s,'min-units','minₖ Dₖ, đơn vị Mbit/user, cùng sáu lần chạy',56,105,848,36,25);
const minRows=[['L\n(Mbit/user)','Joint PSO','Full PSO','Full IPSO'],...results.map(r=>[f(r.L,r.L%1?1:0),...r.metrics.map(m=>f(m.minBits/1e6,4)+(m.feasible?'':' *'))])];
const minTable=table(s,'Minimum_data_summary',minRows,159,329);
for(let r=0;r<results.length;r++)for(let c=0;c<3;c++)if(!results[r].metrics[c].feasible)minTable.getCell(r+1,c+1).text.style={typeface:'Lato',fontSize:25,color:'#888888',alignment:'center',verticalAlignment:'middle'};
text(s,'min-result','Joint PSO đạt L ≤ 2. Hai bản Full đạt cả sáu mức L.\n* Chưa đạt yêu cầu. Giá trị in tròn bằng L có thể còn dư rất nhỏ.',56,513,848,58,21,{color:gray});
text(s,'alpha-caveat','Ghi chú α: ảnh L = 0 cho thấy Joint PSO còn lệch 0,2.\nCác log L > 0 không lưu trace α, nên chưa xác nhận được\nmức L nào làm α không hội tụ về 0,2.',56,583,848,68,20,{color:red,bold:true});
notes(s,'Nguồn: totalBitsPerUser trong phần RF EE của sáu console log và feasible chính thức trong log. Giá trị min lấy từ năm user vật lý, không phải min theo hạng kênh. Do MATLAB in vector 4 chữ số, min D_k làm tròn có thể bằng L nhưng độ chính xác đủ để xác nhận khả thi phải lấy từ flag feasible/dataQoSFeasible trong log; không suy ra vi phạm từ làm tròn. Giới hạn dữ liệu: các log không có alphaTrace hoặc alphaUserHistory, không có workspace .mat, nên không thể xác định từng cấu hình L>0 có alpha=0.2 hoặc không, cũng không suy ra điều này từ fitness, min D hay feasibility. Người dùng mới xác nhận ảnh đi kèm là L=0. Vì vậy phần chú thích nêu rõ bằng chứng và phần chưa xác nhận, không tự gán L=3/4/4.2 là mốc alpha thay đổi.');

await fs.mkdir(path.join(BUILD,'previews'),{recursive:true});
for(let i=0;i<p.slides.items.length;i++){
 const slide=p.slides.items[i];
 const png=await p.export({slide,format:'png',scale:1.25});
 await fs.writeFile(path.join(BUILD,'previews',`slide-${i+1}.png`),new Uint8Array(await png.arrayBuffer()));
 const layout=await slide.export({format:'layout'});
 await fs.writeFile(path.join(BUILD,'previews',`slide-${i+1}.json`),await layout.text());
}
await (await PresentationFile.exportPptx(p)).save(CANDIDATE);
const fontPolicy={basis:'reference',families:['Lato'],referencePath:SOURCE,referenceSha256:createHash('sha256').update(await fs.readFile(SOURCE)).digest('hex')};
const final=await finalizePresentation({workspaceDir:ROOT,candidatePath:CANDIDATE,finalPath:FINAL,pythonExecutable:PYTHON,integrityValidatorPath:path.join(SKILL,'container_tools/inspect_presentation_package_integrity.py'),layoutValidatorPath:path.join(SKILL,'container_tools/inspect_presentation_layout_geometry.py'),layoutArgs:['--expected-slide-size-emu','9144000,6858000','--validate-bullet-geometry','--validate-heading-fit','--require-native-table-slide','7','--require-native-table-slide','8'],requiredNativeTableOwnerSlides:[7,8],fontPolicy,verifyArtifactToolImport:true,receiptPath:path.join(BUILD,'HUST_Alpha_L.validation.json')});
console.log(JSON.stringify({finalPath:FINAL,slides:p.slides.items.length,result:final}));
