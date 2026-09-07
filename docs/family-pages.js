const languageKey="foxly-updater-language";
function setPageLanguage(language,persist=true){
  document.documentElement.lang=language;
  document.querySelectorAll("[data-de][data-en]").forEach((element)=>{element.innerHTML=element.dataset[language]});
  document.querySelectorAll(".lang-button").forEach((button)=>button.classList.toggle("active",button.dataset.language===language));
  const body=document.body;
  document.title=body.dataset[`title${language==="de"?"De":"En"}`]||document.title;
  if(persist)localStorage.setItem(languageKey,language);
}
document.querySelectorAll(".lang-button").forEach((button)=>button.addEventListener("click",()=>setPageLanguage(button.dataset.language)));
document.getElementById("copyrightYear").textContent=new Date().getFullYear();
setPageLanguage(localStorage.getItem(languageKey)||(navigator.language.toLowerCase().startsWith("de")?"de":"en"),false);

const tocLinks=[...document.querySelectorAll(".toc a")];
if(tocLinks.length){
  const sections=tocLinks.map((link)=>document.getElementById(link.getAttribute("href").slice(1))).filter(Boolean);
  const setCurrent=(id)=>tocLinks.forEach((link)=>link.classList.toggle("current",link.getAttribute("href")===`#${id}`));
  const observer=new IntersectionObserver((entries)=>{
    const visible=entries.filter((entry)=>entry.isIntersecting).sort((a,b)=>a.boundingClientRect.top-b.boundingClientRect.top);
    if(visible.length)setCurrent(visible[0].target.id);
  },{rootMargin:"-20% 0px -70% 0px"});
  sections.forEach((section)=>observer.observe(section));
}
