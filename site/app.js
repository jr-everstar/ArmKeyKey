const modes = {
  cangjie: { number: '01', prefix: '讓文字，自然', title: '手指記得的倉頡。', description: '保留 YahooKeyKey／OpenVanilla 字表的相對選字順序與輸入引擎。練熟的字根，不用重新適應。', output: '明亮', reading: '日 月', word: '明', note: '日月 · AB', keys: [['A', '日'], ['B', '月'], ['space', '轉換']] },
  simplex: { number: '02', prefix: '讓文字，自然', title: '兩個字根，一份默契。', description: '取首尾兩碼，自動組字。速成預設關閉頻率學習，保留熟悉的選字順序，讓肌肉記憶繼續帶路。', output: '明亮', reading: '日 月', word: '明', note: '首尾 · AB', keys: [['A', '日'], ['B', '月']] },
  jyutping: { number: '03', prefix: '用廣東話，講聲', title: '點樣講，就點樣打。', description: '輸入 neihou 或 nei5hou2，就能選「你好」。支援全有聲調或全無聲調的整詞查找，字詞在本機離線處理。', output: '你好', reading: 'nei5hou2', word: '你好', note: '粵拼 · Jyutping', keys: [['nei5', '你'], ['hou2', '好'], ['space', '轉換']] }
};
document.querySelectorAll('[data-mode]').forEach(button => {
  button.addEventListener('click', () => {
    const mode = modes[button.dataset.mode];
    document.querySelectorAll('[data-mode]').forEach(item => {
      item.classList.toggle('active', item === button);
      item.setAttribute('aria-pressed', String(item === button));
    });
    const fields = { 'demo-prefix': 'prefix', 'mode-number': 'number', 'mode-title': 'title', 'mode-description': 'description', 'demo-output': 'output', reading: 'reading', 'candidate-word': 'word', 'candidate-note': 'note' };
    Object.entries(fields).forEach(([id, key]) => { document.getElementById(id).textContent = mode[key]; });
    document.getElementById('demo-keys').replaceChildren(...mode.keys.map(([key, label]) => {
      const element = document.createElement('kbd');
      element.append(document.createTextNode(key));
      const detail = document.createElement('span');
      detail.textContent = label;
      element.append(detail);
      if (key === 'space') element.className = 'space';
      return element;
    }));
  });
});
