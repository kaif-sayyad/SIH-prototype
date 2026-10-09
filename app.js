/* SkillPath portal: front-end prototype (no backend).
   Replace the DUMMY DATA and the stub functions marked "BACKEND" with real API calls later. */

/* ---------- DUMMY DATA (illustrative only) ---------- */
const SRC = "Dummy hackathon dataset, 2026-01";
const TRADES = {
  Electrician: { interest: "electrical", nsqf: 4, months: 12, cost: 9000,
    steps: ["Training (ITI)", "Electrical Helper", "Electrician", "Senior Electrician", "Supervisor"],
    further: "Diploma in Electrical Engineering (lateral entry), NSQF Level 5",
    loc: { Nagpur: [78, 18000], Pune: [82, 20000], Mumbai: [80, 21000] } },
  "Solar Technician": { interest: "solar", nsqf: 4, months: 6, cost: 12000,
    steps: ["Training", "Solar PV Installer", "Solar Technician", "Site Supervisor", "Project Coordinator"],
    further: "Diploma in Renewable Energy, B.Voc Renewable Energy",
    loc: { Nagpur: [79, 18500], Pune: [84, 20500] } },
  "CNC Operator": { interest: "machining", nsqf: 4, months: 9, cost: 18000,
    steps: ["Training", "CNC Operator", "Machine Setter", "CNC Programmer", "Production Supervisor"],
    further: "Diploma in Mechanical Engineering (lateral entry), NSQF Level 5",
    loc: { Mumbai: [81, 22000], Pune: [85, 23500] } },
  Plumber: { interest: "plumbing", nsqf: 3, months: 6, cost: 6000,
    steps: ["Training", "Plumber Helper", "Plumber", "Senior Plumber", "Contractor"],
    further: "NSQF Level 4, Diploma in Civil Engineering (lateral entry)",
    loc: { Nagpur: [72, 15000], Pune: [76, 17000] } },
  Welder: { interest: "welding", nsqf: 3, months: 6, cost: 8000,
    steps: ["Training", "Welder Helper", "Arc Welder", "Senior Welder", "Fabrication Supervisor"],
    further: "NSQF Level 4, Diploma in Mechanical Engineering (lateral entry)",
    loc: { Mumbai: [74, 19000], Nagpur: [70, 16500] } },
  "Automotive Technician": { interest: "auto", nsqf: 4, months: 12, cost: 14000,
    steps: ["Training", "Trainee Technician", "Technician", "Senior Technician", "Service Supervisor"],
    further: "Diploma in Automobile Engineering (lateral entry), NSQF Level 5",
    loc: { Pune: [80, 19500], Nagpur: [75, 17000] } },
};
const CONCERNS = [
  ["income", "💰", "Income", "कमाई"], ["job", "🏢", "Job security", "नोकरी"],
  ["social", "👪", "Social perception", "समाजातील प्रतिष्ठा"], ["growth", "📈", "Career growth", "करिअर ग्रोथ"],
  ["safety", "🛡️", "Safety", "सुरक्षा"], ["edu", "🎓", "Further education", "पुढील शिक्षण"],
  ["cost", "🧾", "Training cost", "प्रशिक्षण खर्च"], ["localjobs", "📍", "Local jobs", "स्थानिक नोकऱ्या"],
];
const KEYWORDS = {
  income: ["salary", "earn", "income", "money", "कमाई", "पगार"], job: ["job", "placement", "नोकरी"],
  social: ["society", "respect", "relatives", "status", "समाज"], growth: ["growth", "promotion", "future", "प्रगती", "भविष्य"],
  safety: ["safe", "danger", "accident", "सुरक्षा"], edu: ["study", "degree", "diploma", "शिक्षण"],
  cost: ["fee", "cost", "afford", "खर्च"], localjobs: ["near", "local", "nearby", "जवळ"],
};
const ADMIN_DEMO = {
  total: 1240, completed: 910, ai: 1020, esc: 220,
  concerns: [["Job security", 32], ["Income", 25], ["Social perception", 18], ["Further education", 12], ["Safety", 8], ["Other", 5]],
  loc: [["Nagpur", "Job security", "Income", 410], ["Pune", "Income", "Career growth", 520], ["Mumbai", "Social perception", "Job security", 310]],
};
const I18N = {
  en: { title: "SkillPath Family Counselling Portal", subtitle: "Informed career decisions for students and families",
        nav_login: "Login", nav_student: "Student Profile", nav_family: "Family Context", nav_counsel: "Counselling",
        nav_recs: "Recommendations", nav_pathway: "Pathway & Compare", nav_result: "Family Summary", nav_admin: "Admin Dashboard",
        bot_title: "Ask the AI Counsellor" },
  mr: { title: "स्किलपाथ कौटुंबिक समुपदेशन पोर्टल", subtitle: "विद्यार्थी व कुटुंबांसाठी माहितीपूर्ण करिअर निर्णय",
        nav_login: "लॉगिन", nav_student: "विद्यार्थी माहिती", nav_family: "कौटुंबिक माहिती", nav_counsel: "समुपदेशन",
        nav_recs: "शिफारसी", nav_pathway: "मार्ग व तुलना", nav_result: "कुटुंब सारांश", nav_admin: "प्रशासक डॅशबोर्ड",
        bot_title: "AI समुपदेशकाला विचारा" },
};
const NODATA = "Verified data for this specific trade/location is currently unavailable.";

/* ---------- STATE ---------- */
const ORDER = ["login", "student", "family", "counsel", "recs", "pathway", "result"];
const S = { role: null, lang: "en", unlocked: 0, profile: {}, concerns: [], asked: new Set(), unresolved: new Set(), recs: [], trade: null, escalated: false };
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];

/* ---------- NAVIGATION ---------- */
function go(page) {
  $$("section[data-page]").forEach(s => s.hidden = s.dataset.page !== page);
  const idx = ORDER.indexOf(page);
  $$(".taskbar button").forEach(b => {
    const i = ORDER.indexOf(b.dataset.go);
    b.classList.toggle("active", b.dataset.go === page);
    b.classList.toggle("done", i >= 0 && i < idx && !b.classList.contains("admin-tab"));
    if (i >= 0) b.disabled = S.role === null ? i > 0 : i > S.unlocked;
  });
  if (page === "recs") renderRecs();
  if (page === "pathway") renderPathway();
  if (page === "result") renderResult();
  if (page === "admin") renderAdmin();
  window.scrollTo({ top: 0 });
}
function unlock(page) { S.unlocked = Math.max(S.unlocked, ORDER.indexOf(page)); }
document.addEventListener("click", e => {
  const t = e.target.closest("[data-go]");
  if (!t || t.disabled) return;
  const p = t.dataset.go;
  if (ORDER.includes(p)) unlock(p);
  go(p);
});

/* ---------- 1. AUTH (BACKEND: replace with real OTP / login API) ---------- */
let role = "family";
$$("#roleTabs button").forEach(b => b.onclick = () => {
  role = b.dataset.role;
  $$("#roleTabs button").forEach(x => x.classList.toggle("on", x === b));
});
$("#otpBtn").onclick = () => {
  if (!/^\d{10}$/.test($("#mobile").value)) return $("#loginErr").textContent = "Enter a valid 10-digit mobile number.";
  $("#loginErr").textContent = ""; $("#otp").disabled = false; $("#otp").focus();
  $("#otpBtn").textContent = "OTP sent";
};
$("#loginForm").onsubmit = e => {
  e.preventDefault();
  const code = $("#otp").value;
  const ok = role === "admin" ? code === "admin123" : code === "123456";
  if (!ok) return $("#loginErr").textContent = "Incorrect OTP / password (demo: 123456, admin: admin123).";
  S.role = role; setLang($("#langSel").value);
  $("#userbox").hidden = false; $("#userLabel").textContent = (role === "admin" ? "Administrator" : "Family") + " · " + $("#mobile").value.replace(/\d(?=\d{4})/g, "x");
  addBot("Hello! I can explain earnings, placement, career growth and more. Tap a topic or type a question.");
  if (role === "admin") { $(".admin-tab").hidden = false; go("admin"); }
  else { unlock("student"); go("student"); }
};
function logout() { location.reload(); }

/* ---------- 2-3. FORMS ---------- */
$("#fConcerns").innerHTML = CONCERNS.map(c => `<label class="chip"><input type="checkbox" value="${c[0]}">${c[1]} ${c[2]}</label>`).join("");
$("#fConcerns").onchange = e => e.target.closest("label").classList.toggle("on", e.target.checked);
$$("form[data-next]").forEach(f => f.onsubmit = e => {
  e.preventDefault();
  $$("input, select", f).forEach(el => { if (el.id) S.profile[el.id] = el.value; });
  if (f.dataset.next === "counsel") S.concerns = $$("#fConcerns input:checked").map(i => i.value);
  if (f.dataset.next === "family") computeRecs();
  unlock(f.dataset.next); go(f.dataset.next);
  if (f.dataset.next === "counsel") renderCounsel();
});

/* ---------- RECOMMENDATION (BACKEND: replace with matching engine API) ---------- */
function rowFor(trade, loc) { const r = TRADES[trade].loc[loc]; return r ? { placement: r[0], earn: r[1] } : null; }
function computeRecs() {
  const { sInterest, sLoc, sMonths } = S.profile;
  S.recs = Object.keys(TRADES).map(name => {
    const t = TRADES[name], r = rowFor(name, sLoc);
    const score = (t.interest === sInterest ? 3 : 0) + (r ? 1 + r.placement / 100 : 0) - (t.months > +sMonths ? 1.5 : 0);
    return { name, score };
  }).sort((a, b) => b.score - a.score).slice(0, 3).map(x => x.name);
  S.trade = S.recs[0];
}

/* ---------- 4. COUNSELLING ---------- */
function concernAnswer(key, trade = S.trade, loc = S.profile.sLoc) {
  const t = TRADES[trade], r = rowFor(trade, loc);
  const src = `\n(Source: ${SRC})`;
  if (key === "safety" || key === "social") return { text: "We do not have verified data on this topic yet.\nA human counsellor can discuss it with you.", ok: false };
  if (key === "cost") return { text: `${trade}: about ${t.months} months, estimated fee ₹${t.cost.toLocaleString("en-IN")}.${src}`, ok: true };
  if (key === "growth") return { text: `Typical path: ${t.steps.join(" → ")}. NSQF level ${t.nsqf}.${src}`, ok: true };
  if (key === "edu") return { text: `After ${trade}: ${t.further}.${src}`, ok: true };
  if (key === "localjobs") {
    const list = Object.entries(t.loc).map(([l, v]) => `${l} ${v[0]}%`).join(", ");
    return { text: `Placement for ${trade} by city: ${list}.${r ? "" : "\n" + NODATA}${src}`, ok: !!r };
  }
  if (!r) return { text: NODATA + "\nA human counsellor can help.", ok: false };
  if (key === "income") return { text: `${trade} in ${loc}: average earnings ₹${r.earn.toLocaleString("en-IN")} per month.${src}`, ok: true };
  if (key === "job") return { text: `${trade} in ${loc}: ${r.placement}% of trainees were placed in jobs.${src}`, ok: true };
}
function showConcern(key) {
  const c = CONCERNS.find(x => x[0] === key), a = concernAnswer(key);
  S.asked.add(key); a.ok ? S.unresolved.delete(key) : S.unresolved.add(key);
  const box = $("#concernAnswer"); box.hidden = false; box.className = "answer" + (a.ok ? "" : " warn");
  box.textContent = `${c[1]} ${c[2]} (${S.trade}, ${S.profile.sLoc})\n\n${a.text}`;
  return a;
}
function renderCounsel() {
  $("#counselChips").innerHTML = CONCERNS.map(c => `<button data-c="${c[0]}" class="${S.concerns.includes(c[0]) ? "on" : ""}">${c[1]} ${c[S.lang === "mr" ? 3 : 2]}</button>`).join("");
  $$("#counselChips button").forEach(b => b.onclick = () => showConcern(b.dataset.c));
}

/* ---------- 5. RECOMMENDATIONS ---------- */
function renderRecs() {
  const loc = S.profile.sLoc;
  $("#recsIntro").textContent = `For ${S.profile.sName || "the student"} in ${loc}, interest: ${$("#sInterest").selectedOptions[0].text}.`;
  $("#recCards").innerHTML = S.recs.map(n => {
    const t = TRADES[n], r = rowFor(n, loc);
    return `<div class="card"><h3>${n}</h3>
      ${r ? '<span class="badge">Verified data</span>' : '<span class="badge warn">No data for ' + loc + "</span>"}
      <dl><dt>Placement</dt><dd>${r ? r.placement + "%" : "Unavailable"}</dd>
      <dt>Avg earnings</dt><dd>${r ? "₹" + r.earn.toLocaleString("en-IN") + "/month" : "Unavailable"}</dd>
      <dt>NSQF level</dt><dd>${t.nsqf}</dd><dt>Duration</dt><dd>${t.months} months</dd>
      <dt>Est. fee</dt><dd>₹${t.cost.toLocaleString("en-IN")}</dd></dl>
      <div class="src">Source: ${SRC}</div></div>`;
  }).join("");
}

/* ---------- 6. PATHWAY + COMPARE ---------- */
function renderPathway() {
  $("#pathTabs").innerHTML = S.recs.map(n => `<button class="${n === S.trade ? "on" : ""}" data-t="${n}">${n}</button>`).join("");
  $$("#pathTabs button").forEach(b => b.onclick = () => { S.trade = b.dataset.t; renderPathway(); });
  $("#pathSteps").innerHTML = TRADES[S.trade].steps.map(s => `<li>${s}</li>`).join("");
  $("#pathFurther").textContent = TRADES[S.trade].further;
  const t = TRADES[S.trade];
  $("#cmpBody").innerHTML = [
    ["Entry requirement", S.profile.sEdu + " pass", "12th pass (typical)"],
    ["Training duration", t.months + " months", "3 years (typical)"],
    ["Initial roles", t.steps[1], "Data to be added"],
    ["Further education", t.further, "Post-graduation, competitive exams"],
    ["Career progression", t.steps.slice(1).join(" → "), "Data to be added"],
    ["Local opportunities", rowFor(S.trade, S.profile.sLoc) ? rowFor(S.trade, S.profile.sLoc).placement + "% placement in " + S.profile.sLoc : NODATA, "Data to be added"],
  ].map(r => `<tr><td>${r[0]}</td><td>${r[1]}</td><td>${r[2]}</td></tr>`).join("");
}

/* ---------- 7. RESULT ---------- */
function renderResult() {
  const name = k => CONCERNS.find(c => c[0] === k)[2];
  const asked = [...new Set([...S.concerns, ...S.asked])];
  const unresolved = [...S.unresolved];
  const li = a => a.length ? "<ul>" + a.map(x => `<li>${x}</li>`).join("") + "</ul>" : "<p>None</p>";
  const date = new Date().toLocaleDateString("en-IN");
  $("#resultBody").innerHTML = `
    <p><b>Date:</b> ${date} &nbsp; <b>Student:</b> ${S.profile.sName || "-"} &nbsp; <b>Location:</b> ${S.profile.sLoc}</p>
    <h3>Student interest</h3><p>${$("#sInterest").selectedOptions[0].text}. Goal: ${S.profile.sGoal || "-"}</p>
    <h3>Recommended pathways</h3><ol>${S.recs.map(n => { const r = rowFor(n, S.profile.sLoc);
      return `<li><b>${n}</b>: ${r ? r.placement + "% placement, ₹" + r.earn.toLocaleString("en-IN") + "/month" : NODATA}</li>`; }).join("")}</ol>
    <h3>Parent concerns</h3>${li(asked.map(name))}
    <h3>Information discussed</h3>${li([...S.asked].filter(k => !S.unresolved.has(k)).map(name))}
    <h3>Unresolved concerns</h3>${li(unresolved.map(name))}
    <h3>Next step</h3><p>${unresolved.length || S.escalated ? "Connect with a human counsellor." : "Discuss the options together at home."}</p>
    <p class="note">Data source: ${SRC}. Figures are illustrative.</p>`;
}
$("#escBtn").onclick = () => { S.escalated = true; $("#escMsg").hidden = false; };

/* ---------- ADMIN (BACKEND: replace with aggregated analytics API) ---------- */
function renderAdmin() {
  const d = ADMIN_DEMO;
  $("#adminStats").innerHTML = [["Families counselled", d.total], ["Completed sessions", d.completed], ["AI-resolved", d.ai], ["Human escalations", d.esc]]
    .map(x => `<div><b>${x[1].toLocaleString("en-IN")}</b>${x[0]}</div>`).join("");
  $("#adminBars").innerHTML = d.concerns.map(c => `<div>${c[0]} <b>${c[1]}%</b></div><div class="bar"><i style="width:${c[1] * 2.5}%"></i></div>`).join("");
  $("#adminLoc").innerHTML = d.loc.map(r => `<tr>${r.map(x => `<td>${x}</td>`).join("")}</tr>`).join("");
}

/* ---------- LANGUAGE ---------- */
function setLang(l) {
  S.lang = l; document.documentElement.lang = l;
  $$("[data-i18n]").forEach(el => { el.textContent = I18N[l][el.dataset.i18n] || el.textContent; });
  if (S.role) renderCounsel();
  renderBotChips();
}

/* ---------- AI BOT (bottom middle) ---------- */
function addBot(text, me) {
  const d = document.createElement("div"); d.className = "msg " + (me ? "me" : "ai"); d.textContent = text;
  $("#botLog").appendChild(d); $("#botLog").scrollTop = 1e6;
}
function renderBotChips() {
  $("#botChips").innerHTML = CONCERNS.slice(0, 6).map(c => `<button data-c="${c[0]}">${c[1]} ${c[S.lang === "mr" ? 3 : 2]}</button>`).join("");
  $$("#botChips button").forEach(b => b.onclick = () => botAsk(CONCERNS.find(c => c[0] === b.dataset.c)[2], b.dataset.c));
}
/* BACKEND: replace botAsk's reply logic with a call to the RAG/LLM API */
function botAsk(text, forced) {
  addBot(text, true);
  if (!S.role || !S.trade) return addBot("Please complete your student profile first so I can use your location and interest.");
  const lower = text.toLowerCase();
  const key = forced || Object.keys(KEYWORDS).find(k => KEYWORDS[k].some(w => lower.includes(w)));
  if (/counsellor|human|समुपदेशक/.test(lower)) { S.escalated = true; return addBot("I have flagged your request for a human counsellor."); }
  if (!key) return addBot("I can help with income, jobs, career growth, safety, further education, cost and local jobs. Which one worries you?");
  const a = concernAnswer(key);
  S.asked.add(key); a.ok ? S.unresolved.delete(key) : S.unresolved.add(key);
  addBot(a.text + (a.ok ? "" : "\nI am flagging this for a human counsellor."));
}
$("#botToggle").onclick = () => {
  const open = $("#botPanel").hidden;
  $("#botPanel").hidden = !open; $("#botToggle").setAttribute("aria-expanded", open);
};
$("#botForm").onsubmit = e => { e.preventDefault(); const v = $("#botInput").value.trim(); if (v) { $("#botInput").value = ""; botAsk(v); } };
$("#micBtn").onclick = () => {
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SR) return alert("Voice input is not supported in this browser.");
  const r = new SR(); r.lang = S.lang === "mr" ? "mr-IN" : "en-IN";
  r.onresult = ev => { $("#botInput").value = ev.results[0][0].transcript; };
  r.start();
};

renderBotChips();
go("login");
