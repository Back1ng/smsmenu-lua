local M = {}

local CONFIG = nil

local TEXTS = {
    en = {
        app_title = "SMS Messenger",
        search = "Search",
        nothing_found = "Nothing found",
        no_messages = "No messages",
        theme_to_dark = "Switch to dark theme",
        theme_to_light = "Switch to light theme",
        settings = "Settings",
        new_conversation = "New conversation",
        close = "Close",
        back_to_contacts = "Back to contacts",
        contact_actions = "Contact actions",
        call_contact = "Call contact",
        edit_contact = "Edit contact",
        delete_contact = "Delete contact",
        status_online = "online",
        status_offline = "offline",
        today = "Today",
        yesterday = "Yesterday",
        your_messages = "Your messages",
        select_contact_hint = "Select a contact to start chatting",
        no_messages_yet = "No messages yet",
        first_message_hint = "Send a message to start the conversation",
        type_message = "Type a message...",
        send = "Send",
        new_contact = "New Contact",
        start_conversation_title = "Start a new conversation",
        start_conversation_hint = "Add a phone number to begin messaging.",
        phone_number = "Phone number",
        enter_phone = "Enter phone number",
        contact_name = "Contact name",
        optional = "Optional",
        cancel = "Cancel",
        start_chat = "Start chat",
        default_contact_name = "Contact %s",
        confirm_delete = "Confirm Delete",
        delete_conversation_title = "Delete this conversation?",
        delete_conversation_hint = "The contact and message history will be removed.",
        irreversible_warning = "This action cannot be undone.",
        delete = "Delete",
        edit_contact_title = "Edit Contact",
        contact_details = "Contact details",
        contact_details_hint = "Update the name or phone number for this chat.",
        enter_contact_name = "Enter contact name",
        save_changes = "Save changes",
        section_notifications = "NOTIFICATIONS",
        sound_notifications = "Sound notifications",
        sound_notifications_hint = "Play a sound for new messages",
        screen_notifications = "On-screen notifications",
        screen_notifications_hint = "Banners that do not block mouse input",
        messenger_only_sms = "Messenger-only SMS",
        messenger_only_sms_hint = "Hide SMS messages from game chat",
        section_sound = "SOUND",
        alert_sound = "Alert sound",
        notification_volume = "Notification volume",
        play_selected_sound = "Play selected sound",
        no_sounds_found = "No sounds found in smsmenu/alerts/",
        section_controls = "CONTROLS",
        menu_hotkey = "Open or close messenger",
        menu_hotkey_hint = "Click the button, then press a key (Esc cancels)",
        press_hotkey = "Press a key...",
        section_appearance = "APPEARANCE",
        interface_scale = "Interface scale",
        language = "Language",
        english = "English",
        russian = "Русский",
        done = "Done"
    },
    ru = {
        app_title = "SMS Мессенджер",
        search = "Поиск",
        nothing_found = "Ничего не найдено",
        no_messages = "Нет сообщений",
        theme_to_dark = "Включить тёмную тему",
        theme_to_light = "Включить светлую тему",
        settings = "Настройки",
        new_conversation = "Новый диалог",
        close = "Закрыть",
        back_to_contacts = "Вернуться к контактам",
        contact_actions = "Действия с контактом",
        call_contact = "Позвонить контакту",
        edit_contact = "Изменить контакт",
        delete_contact = "Удалить контакт",
        status_online = "в сети",
        status_offline = "не в сети",
        today = "Сегодня",
        yesterday = "Вчера",
        your_messages = "Ваши сообщения",
        select_contact_hint = "Выберите контакт, чтобы начать общение",
        no_messages_yet = "Сообщений пока нет",
        first_message_hint = "Отправьте первое сообщение",
        type_message = "Введите сообщение...",
        send = "Отправить",
        new_contact = "Новый контакт",
        start_conversation_title = "Начать новый диалог",
        start_conversation_hint = "Добавьте номер телефона, чтобы начать общение.",
        phone_number = "Номер телефона",
        enter_phone = "Введите номер телефона",
        contact_name = "Имя контакта",
        optional = "Необязательно",
        cancel = "Отмена",
        start_chat = "Начать диалог",
        default_contact_name = "Контакт %s",
        confirm_delete = "Подтверждение удаления",
        delete_conversation_title = "Удалить этот диалог?",
        delete_conversation_hint = "Контакт и история сообщений будут удалены.",
        irreversible_warning = "Это действие нельзя отменить.",
        delete = "Удалить",
        edit_contact_title = "Изменить контакт",
        contact_details = "Данные контакта",
        contact_details_hint = "Измените имя или номер телефона этого контакта.",
        enter_contact_name = "Введите имя контакта",
        save_changes = "Сохранить",
        section_notifications = "УВЕДОМЛЕНИЯ",
        sound_notifications = "Звуковые уведомления",
        sound_notifications_hint = "Воспроизводить звук для новых сообщений",
        screen_notifications = "Экранные уведомления",
        screen_notifications_hint = "Баннеры без блокировки мыши",
        messenger_only_sms = "SMS только в мессенджере",
        messenger_only_sms_hint = "Скрывать SMS в игровом чате",
        section_sound = "ЗВУК",
        alert_sound = "Звук уведомления",
        notification_volume = "Громкость уведомлений",
        play_selected_sound = "Прослушать выбранный звук",
        no_sounds_found = "В папке smsmenu/alerts/ нет звуков",
        section_controls = "УПРАВЛЕНИЕ",
        menu_hotkey = "Открыть или закрыть мессенджер",
        menu_hotkey_hint = "Нажмите кнопку, затем клавишу (Esc — отмена)",
        press_hotkey = "Нажмите клавишу...",
        section_appearance = "ОФОРМЛЕНИЕ",
        interface_scale = "Масштаб интерфейса",
        language = "Язык",
        english = "English",
        russian = "Русский",
        done = "Готово"
    }
}

local MONTHS = {
    en = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" },
    ru = { "января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря" }
}

function M.init(deps)
    CONFIG = deps.CONFIG
end

function M.language()
    return CONFIG and CONFIG.language == "ru" and "ru" or "en"
end

function M.t(key, ...)
    local language = M.language()
    local text = (TEXTS[language] and TEXTS[language][key]) or TEXTS.en[key] or key
    if select("#", ...) > 0 then
        return string.format(text, ...)
    end
    return text
end

function M.month(index)
    local months = MONTHS[M.language()] or MONTHS.en
    return months[index] or tostring(index)
end

function M.popupTitle(key, stableId)
    return M.t(key) .. "###" .. stableId
end

return M
