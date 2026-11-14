-- Translations. Keys are the English strings used in code (Waypost.L["..."]),
-- so anything not translated yet simply shows in English.
-- To add a language: copy a block, change the locale code, translate the values.
-- Guide text itself (step titles, tips) is not translated here.

local W = Waypost
local locale = GetLocale and GetLocale() or "enUS"

local function apply(code, t)
	if locale ~= code and not (code == "esES" and locale == "esMX") then return end
	for k, v in pairs(t) do rawset(W.L, k, v) end
end

apply("deDE", {
	["Accept"] = "Annehmen", ["Turn in"] = "Abgeben", ["Complete"] = "Abschließen", ["Kill"] = "Töte",
	["Collect"] = "Sammle", ["Buy"] = "Kaufe", ["Use"] = "Benutze", ["Talk to"] = "Sprich mit",
	["Interact with"] = "Interagiere mit", ["Go to"] = "Gehe zu", ["Enter"] = "Betritt", ["Explore"] = "Erkunde",
	["Reach level %d"] = "Erreiche Stufe %d", ["Visit your class trainer"] = "Besuche deinen Klassenlehrer",
	["Fly to"] = "Fliege nach", ["Get the flight path"] = "Hole den Flugpunkt", ["Set your hearthstone"] = "Setze deinen Ruhestein",
	["Use your hearthstone"] = "Benutze deinen Ruhestein", ["Sell junk and repair"] = "Verkaufe Plunder und repariere",
	["optional"] = "optional", ["Quest"] = "Quest", ["Guides"] = "Guides", ["Settings"] = "Einstellungen",
	["Skip"] = "Überspringen", ["Why?"] = "Warum?", ["Steps"] = "Schritte", ["Start"] = "Starten",
	["All guides"] = "Alle Guides", ["Start guide"] = "Guide starten", ["Continue"] = "Fortsetzen", ["Restart"] = "Neu starten",
	["Next step"] = "Nächster Schritt", ["Previous step"] = "Vorheriger Schritt", ["Here"] = "Hier", ["yd"] = "m",
	["Looking ahead"] = "Vorschau", ["Looking back"] = "Rückblick", ["click to return"] = "klicken zum Zurückkehren",
	["Leveling"] = "Leveln", ["Class"] = "Klasse", ["Custom"] = "Eigene", ["Reputation"] = "Ruf",
	["Professions"] = "Berufe", ["Exploration"] = "Erkundung", ["Collectibles"] = "Sammlungen",
	["No guide loaded. Choose one to begin."] = "Kein Guide geladen. Wähle einen aus.",
})

apply("frFR", {
	["Accept"] = "Accepter", ["Turn in"] = "Rendre", ["Complete"] = "Terminer", ["Kill"] = "Tuer",
	["Collect"] = "Récupérer", ["Buy"] = "Acheter", ["Use"] = "Utiliser", ["Talk to"] = "Parler à",
	["Interact with"] = "Interagir avec", ["Go to"] = "Aller à", ["Enter"] = "Entrer dans", ["Explore"] = "Explorer",
	["Reach level %d"] = "Atteindre le niveau %d", ["Visit your class trainer"] = "Voir votre maître de classe",
	["Fly to"] = "Voler vers", ["Get the flight path"] = "Prendre le point de vol", ["Set your hearthstone"] = "Lier votre pierre de foyer",
	["Use your hearthstone"] = "Utiliser votre pierre de foyer", ["Sell junk and repair"] = "Vendre et réparer",
	["optional"] = "facultatif", ["Quest"] = "Quête", ["Guides"] = "Guides", ["Settings"] = "Options",
	["Skip"] = "Passer", ["Why?"] = "Pourquoi ?", ["Steps"] = "Étapes", ["Start"] = "Démarrer",
	["All guides"] = "Tous les guides", ["Start guide"] = "Démarrer le guide", ["Continue"] = "Continuer", ["Restart"] = "Recommencer",
	["Next step"] = "Étape suivante", ["Previous step"] = "Étape précédente", ["Here"] = "Ici", ["yd"] = "m",
	["Looking ahead"] = "Aperçu", ["Looking back"] = "Retour en arrière", ["click to return"] = "cliquer pour revenir",
	["Leveling"] = "Montée en niveau", ["Class"] = "Classe", ["Custom"] = "Perso", ["Reputation"] = "Réputation",
	["Professions"] = "Métiers", ["Exploration"] = "Exploration", ["Collectibles"] = "Collections",
	["No guide loaded. Choose one to begin."] = "Aucun guide chargé. Choisissez-en un.",
})

apply("esES", {
	["Accept"] = "Aceptar", ["Turn in"] = "Entregar", ["Complete"] = "Completar", ["Kill"] = "Matar",
	["Collect"] = "Recoger", ["Buy"] = "Comprar", ["Use"] = "Usar", ["Talk to"] = "Hablar con",
	["Interact with"] = "Interactuar con", ["Go to"] = "Ir a", ["Enter"] = "Entrar en", ["Explore"] = "Explorar",
	["Reach level %d"] = "Alcanzar el nivel %d", ["Visit your class trainer"] = "Visita a tu instructor de clase",
	["Fly to"] = "Volar a", ["Get the flight path"] = "Consigue la ruta de vuelo", ["Set your hearthstone"] = "Fija tu piedra de hogar",
	["Use your hearthstone"] = "Usa tu piedra de hogar", ["Sell junk and repair"] = "Vender y reparar",
	["optional"] = "opcional", ["Quest"] = "Misión", ["Guides"] = "Guías", ["Settings"] = "Opciones",
	["Skip"] = "Saltar", ["Why?"] = "¿Por qué?", ["Steps"] = "Pasos", ["Start"] = "Empezar",
	["All guides"] = "Todas las guías", ["Start guide"] = "Empezar guía", ["Continue"] = "Continuar", ["Restart"] = "Reiniciar",
	["Next step"] = "Paso siguiente", ["Previous step"] = "Paso anterior", ["Here"] = "Aquí", ["yd"] = "m",
	["Looking ahead"] = "Vista previa", ["Looking back"] = "Mirando atrás", ["click to return"] = "clic para volver",
	["Leveling"] = "Subir de nivel", ["Class"] = "Clase", ["Custom"] = "Propias", ["Reputation"] = "Reputación",
	["Professions"] = "Profesiones", ["Exploration"] = "Exploración", ["Collectibles"] = "Coleccionables",
	["No guide loaded. Choose one to begin."] = "No hay guía cargada. Elige una para empezar.",
})

apply("ptBR", {
	["Accept"] = "Aceitar", ["Turn in"] = "Entregar", ["Complete"] = "Concluir", ["Kill"] = "Matar",
	["Collect"] = "Coletar", ["Buy"] = "Comprar", ["Use"] = "Usar", ["Talk to"] = "Falar com",
	["Interact with"] = "Interagir com", ["Go to"] = "Ir para", ["Enter"] = "Entrar em", ["Explore"] = "Explorar",
	["Reach level %d"] = "Alcançar o nível %d", ["Visit your class trainer"] = "Visite seu instrutor de classe",
	["Fly to"] = "Voar para", ["Get the flight path"] = "Pegue a rota de voo", ["Set your hearthstone"] = "Defina sua pedra de regresso",
	["Use your hearthstone"] = "Use sua pedra de regresso", ["Sell junk and repair"] = "Vender e consertar",
	["optional"] = "opcional", ["Quest"] = "Missão", ["Guides"] = "Guias", ["Settings"] = "Opções",
	["Skip"] = "Pular", ["Why?"] = "Por quê?", ["Steps"] = "Passos", ["Start"] = "Iniciar",
	["All guides"] = "Todos os guias", ["Start guide"] = "Iniciar guia", ["Continue"] = "Continuar", ["Restart"] = "Recomeçar",
	["Next step"] = "Próximo passo", ["Previous step"] = "Passo anterior", ["Here"] = "Aqui", ["yd"] = "m",
	["Looking ahead"] = "Prévia", ["Looking back"] = "Olhando para trás", ["click to return"] = "clique para voltar",
	["Leveling"] = "Evolução", ["Class"] = "Classe", ["Custom"] = "Personalizados", ["Reputation"] = "Reputação",
	["Professions"] = "Profissões", ["Exploration"] = "Exploração", ["Collectibles"] = "Colecionáveis",
	["No guide loaded. Choose one to begin."] = "Nenhum guia carregado. Escolha um para começar.",
})

apply("zhCN", {
	["Accept"] = "接受", ["Turn in"] = "交付", ["Complete"] = "完成", ["Kill"] = "击杀",
	["Collect"] = "收集", ["Buy"] = "购买", ["Use"] = "使用", ["Talk to"] = "对话",
	["Interact with"] = "互动", ["Go to"] = "前往", ["Enter"] = "进入", ["Explore"] = "探索",
	["Reach level %d"] = "达到%d级", ["Visit your class trainer"] = "拜访职业训练师",
	["Fly to"] = "飞往", ["Get the flight path"] = "开启飞行点", ["Set your hearthstone"] = "绑定炉石",
	["Use your hearthstone"] = "使用炉石", ["Sell junk and repair"] = "出售垃圾并修理",
	["optional"] = "可选", ["Quest"] = "任务", ["Guides"] = "指南", ["Settings"] = "设置",
	["Skip"] = "跳过", ["Why?"] = "为什么？", ["Steps"] = "步骤", ["Start"] = "开始",
	["All guides"] = "全部指南", ["Start guide"] = "开始指南", ["Continue"] = "继续", ["Restart"] = "重新开始",
	["Next step"] = "下一步", ["Previous step"] = "上一步", ["Here"] = "已到达", ["yd"] = "码",
	["Looking ahead"] = "预览", ["Looking back"] = "回看", ["click to return"] = "点击返回",
	["Leveling"] = "升级", ["Class"] = "职业", ["Custom"] = "自定义", ["Reputation"] = "声望",
	["Professions"] = "专业", ["Exploration"] = "探索", ["Collectibles"] = "收藏",
	["No guide loaded. Choose one to begin."] = "尚未加载指南。请选择一个开始。",
})
