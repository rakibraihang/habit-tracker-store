(function(){
"use strict";
var notice="", products=[];
function escA(v){return String(v==null?"":v).replace(/[&<>"']/g,function(c){return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]})}
function field(label,name,value,type,extra){return '<label class="admf" style="display:flex;flex-direction:column;gap:5px;font-size:13px">'+label+'<input name="'+name+'" type="'+(type||"text")+'" value="'+escA(value)+'" '+(extra||"")+' required style="width:100%;min-width:0;padding:10px;border:1px solid var(--line);border-radius:8px;background:var(--card);color:var(--ink)"></label>'}
function selectField(label,name,value,opts){return '<label class="admf" style="display:flex;flex-direction:column;gap:5px;font-size:13px">'+label+'<select name="'+name+'" style="width:100%;padding:10px;border:1px solid var(--line);border-radius:8px;background:var(--card);color:var(--ink)">'+opts.map(function(o){return '<option value="'+o[0]+'"'+(value===o[0]?' selected':'')+'>'+o[1]+'</option>'}).join("")+'</select></label>'}
function productForm(p){
var id=p.id, published=!!p.is_published;
return '<form class="admin-product-form spbox" data-admin-product="'+escA(id)+'" style="margin:12px 0;display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:10px">'+
'<div style="grid-column:1/-1;display:flex;justify-content:space-between;gap:12px;align-items:center;flex-wrap:wrap"><b>'+escA(p.name)+'</b><span class="spst">'+(published?'Published':'Unpublished')+'</span></div>'+
field('Product name','name',p.name,'text','maxlength="200"')+
field('URL slug','slug',p.slug,'text','maxlength="160" pattern="[a-z0-9]+(-[a-z0-9]+)*"')+
field('Price (BDT)','price',p.price,'number','min="0" step="0.01"')+
field('Category','category',p.category,'text','maxlength="60"')+
selectField('Product type','product_type',p.product_type,[['physical','Physical'],['digital','Digital']])+
field('Stock (blank = unlimited)','stock_quantity',p.stock_quantity==null?'':p.stock_quantity,'number','min="0" step="1"')+
field('Image path (product-images bucket)','image_path',p.image_path||'','text','maxlength="500"')+
'<label style="grid-column:1/-1;display:flex;flex-direction:column;gap:5px;font-size:13px">Description<textarea name="description" rows="3" maxlength="5000" style="width:100%;padding:10px;border:1px solid var(--line);border-radius:8px;background:var(--card);color:var(--ink)">'+escA(p.description||'')+'</textarea></label>'+
'<label style="display:flex;align-items:center;gap:8px;grid-column:1/-1"><input type="checkbox" name="is_published"'+(published?' checked':'')+'> Publish this product to visitors</label>'+
'<div style="grid-column:1/-1"><button class="spbtn" type="submit">Save product</button></div></form>'
}
function adminPanel(){
var existing=products.length?products.map(productForm).join(''):'<div class="spbox"><b>No products yet</b><p class="mu">Create your first product below. New products are unpublished by default.</p></div>';
return '<section aria-labelledby="admh"><div style="display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap;margin:14px 0"><h2 id="admh" class="sf" style="margin:0;font-size:24px">Secure product manager</h2><button class="spbtn o" type="button" data-sp="go|store">Back to store</button></div>'+
'<div class="spbox" style="margin-bottom:14px"><b>Administrator-only controls</b><p class="mu" style="margin:6px 0 0">Saved directly to Supabase. New products stay unpublished by default. Digital checkout and online payments are not enabled yet.</p>'+(notice?'<p role="status" style="margin:8px 0 0">'+escA(notice)+'</p>':'')+'</div>'+
'<h3 class="sf" style="font-size:20px">Add product</h3><form id="admin-create" class="spbox" style="display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:10px;margin:10px 0 22px">'+
field('Product name','name','','text','maxlength="200" placeholder="Daily Planner"')+
field('URL slug','slug','','text','maxlength="160" pattern="[a-z0-9]+(-[a-z0-9]+)*" placeholder="daily-planner"')+
field('Price (BDT)','price','','number','min="0" step="0.01"')+
selectField('Category','category','book',[['book','Book'],['gadget','Gadget'],['ebook','Ebook'],['course','Course'],['general','General']])+
selectField('Product type','product_type','physical',[['physical','Physical'],['digital','Digital']])+
field('Stock (blank = unlimited)','stock_quantity','','number','min="0" step="1"')+
field('Image path (product-images bucket)','image_path','','text','maxlength="500" placeholder="products/example.jpg"')+
'<label style="grid-column:1/-1;display:flex;flex-direction:column;gap:5px;font-size:13px">Description<textarea name="description" rows="3" maxlength="5000" placeholder="Describe the product clearly." style="width:100%;padding:10px;border:1px solid var(--line);border-radius:8px;background:var(--card);color:var(--ink)"></textarea></label>'+
'<label style="display:flex;align-items:center;gap:8px;grid-column:1/-1"><input type="checkbox" name="is_published"> Publish immediately (physical COD only is currently supported)</label>'+
'<div style="grid-column:1/-1"><button class="spbtn" type="submit">Create product</button></div></form>'+
'<h3 class="sf" style="font-size:20px">Existing products ('+products.length+')</h3>'+existing+'</section>'
}
async function loadProducts(){
if(!window.STORE_CLIENT)return false;
var session=await window.STORE_CLIENT.auth.getSession();
if(session.error||!session.data||!session.data.session){notice='Sign in first using the Cloud Backup panel, then reopen Manage products.';return false}
var res=await window.STORE_CLIENT.functions.invoke('admin-products',{method:'GET'});
if(res.error||!res.data||!Array.isArray(res.data.products)){notice=(res.data&&res.data.error)||(res.error&&res.error.message)||'Could not load products.';return false}
products=res.data.products;notice='Products loaded securely.';return true
}
async function openAdmin(){
if(!window.STORE_CLIENT){notice='Store client is still loading. Try again in a moment.';window.toast&&window.toast(notice);return}
var session=await window.STORE_CLIENT.auth.getSession();
if(session.error||!session.data||!session.data.session){window.toast&&window.toast('Sign in first in the Cloud Backup panel. Then select Manage products.');return}
window.show('shopping');window.SV.pg=null;window.SV.v='admin';notice='Loading secure product manager…';window.renderStore();
var ok=await loadProducts();
window.renderStore();
if(!ok&&window.toast)window.toast(notice)
}
async function saveProduct(form){
var create=form.id==='admin-create',id=form.getAttribute('data-admin-product'),fd=new FormData(form),body={};
['name','slug','description','category','product_type','price','stock_quantity','image_path'].forEach(function(k){body[k]=String(fd.get(k)||'').trim()});
body.price=Number(body.price);body.stock_quantity=body.stock_quantity===''?null:Number(body.stock_quantity);body.currency='BDT';body.is_published=fd.get('is_published')==='on';
if(!create)body.id=id;
var btn=form.querySelector('button[type="submit"]');if(btn){btn.disabled=true;btn.textContent='Saving…'}
try{
var res=await window.STORE_CLIENT.functions.invoke('admin-products',{method:create?'POST':'PATCH',body:body});
if(res.error||(res.data&&res.data.error))throw new Error((res.data&&res.data.error)||(res.error&&res.error.message)||'Could not save product');
notice=create?'Product created.':'Product saved.';
await loadProducts();
await window.initLiveStore();
window.renderStore();window.toast&&window.toast(notice)
}catch(err){notice=String(err&&err.message||'Save failed');window.toast&&window.toast(notice);window.renderStore()}
finally{var b=form.querySelector('button[type="submit"]');if(b){b.disabled=false;b.textContent=create?'Create product':'Save product'}}
}
window.adminPanel=adminPanel;
window.openAdmin=openAdmin;
document.addEventListener('click',function(e){var b=e.target.closest('[data-sp]');if(!b)return;var a=b.dataset.sp.split('|')[0];if(a==='admin'){e.preventDefault();openAdmin()}});
document.addEventListener('submit',function(e){var f=e.target.closest('#admin-create,.admin-product-form');if(!f)return;e.preventDefault();saveProduct(f)});
})();