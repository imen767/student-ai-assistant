const messagesEl=document.getElementById('messages');
const welcomeEl=document.getElementById('welcomeScreen');
const inputEl=document.getElementById('messageInput');
const sendBtn=document.getElementById('sendBtn');
const resetBtn=document.getElementById('resetBtn');
let currentLang='en';
async function sendMessage() {
    // 1. Récupère le texte
    const text=inputEl.value.trim();
    if(text==='') return;  // si vide → rien faire
    // 3. Désactive le bouton pendant l'envoi
    inputEl.value = ''; 
    sendBtn.disabled=true;
    addMessage('user',text);
    // 4. Cache le welcome screen
    if(welcomeEl) welcomeEl.style.display='none';
    // 5. Envoie au backend Flask
    const res = await fetch('/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message: text }),
    });
    // 6. Récupère la réponse
    const data =await res.json();
    //7. reactive le bouton
    addMessage('bot',data.reply);
    sendBtn.disabled=false;
}
function addMessage(role,text){
    // 1. Crée le conteneur du message
    const wrapper=document.createElement('div');
    wrapper.className=`message ${role}`;
    // 2. Crée l'avatar
    const avatar=document.createElement('div');
    avatar.className='avatar';
    avatar.textContent=role==='user'?'👤':'🤖';
    // 3. Crée la bulle de texte
    const bubble=document.createElement('div');
    bubble.className='msg-bubble';
    bubble.textContent=text;
    // 4. Ajoute l'avatar et la bulle au conteneur
    wrapper.appendChild(avatar);
    wrapper.appendChild(bubble);
    // 5. Ajoute le conteneur à la zone de messages
    messagesEl.appendChild(wrapper);
    // 6. Scroll vers le bas
    messagesEl.scrollTop=messagesEl.scrollHeight;


}
// Clic sur le bouton envoyer
sendBtn.addEventListener('click',sendMessage);
// Appuyer sur Entrée dans le textarea
inputEl.addEventListener('keydown',function(e){
    if(e.key==='Enter' && !e.shiftKey){
        e.preventDefault();
        sendMessage();
    }
});
//bouton reset
resetBtn.addEventListener('click', async function() {
  // 1. Appelle le backend
  await fetch('/reset', { method: 'POST' });
  
  // 2. Vide les messages
  messagesEl.innerHTML = '';
  
  // 3. Recrée le welcome screen
  messagesEl.innerHTML = `
    <div class="welcome-screen" id="welcomeScreen">
      <div class="welcome-icon">⚡</div>
      <h2 class="welcome-title">How can I help you?</h2>
      <p class="welcome-sub">Ask me anything about academics, career, or certifications.</p>
      <div class="suggestion-grid">
        <button class="suggestion">Explain neural networks</button>
        <button class="suggestion">Find free Python courses</button>
        <button class="suggestion">Best Microsoft certs for AI dev?</button>
        <button class="suggestion">How to write a tech CV?</button>
      </div>
    </div>
  `;
});
document.querySelectorAll('.language-button').forEach(btn => {
    btn.addEventListener('click',function(){
        currentLang=this.dataset.lang;
        // Met à jour le bouton actif
        document.querySelectorAll('.language-button').forEach(b => {b.classList.remove('active')});
        this.classList.add('active');
        inputEl.placeholder = currentLang === 'fr' 
        ? 'Posez votre question...' 
        : 'Ask anything...';


    });
});