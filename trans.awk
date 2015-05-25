#!/usr/bin/gawk -f

# This is free and unencumbered software released into the
# public domain.
#
# This software is provided for the purpose of personal, reasonable
# and convenient human use of the Google Translate Service, i.e.,
# only for those who feel that their terminal is more accessible
# than a web browser. For other purposes, please use the official
# Google Translate API <https://developers.google.com/translate/>.
#
# By using this software, you ("the user") agree that:
#
# 1. Neither this software nor its author is affiliated with
# Google Inc. ("Google").
#
# 2. By using this software, the user is de facto using web
# services provided by Google, therefore they are obliged to
# follow the Google Terms of Service.
#
# 3. This software is provided "as is". The user of this software
# shall be fully liable for any possible infringement of, including
# but not limited to, the Google Terms of Service; per contra,
# the user must be aware that their data might be collected by
# Google, therefore they shall be liable for their own privacy
# concern, including but not limited to, possible disclosure of
# personal information. See the (un)LICENSE file for more details.

BEGIN {
    Name        = "Translate Shell"
    Description = "Google Translate to serve as a command-line tool"
    Version     = "0.8.24"
    Command     = "trans"
    EntryPoint  = "translate.awk"
}

function initConst() {
    STDIN  = "/dev/stdin"
    STDOUT = "/dev/stdout"
    STDERR = "/dev/stderr"
    SUPOUT = " > /dev/null "
    SUPERR = " 2> /dev/null "
}
function initUrlEncoding() {
    UrlEncoding["\n"] = "%0A"
    UrlEncoding[" "]  = "%20"
    UrlEncoding["!"]  = "%21"
    UrlEncoding["\""] = "%22"
    UrlEncoding["#"]  = "%23"
    UrlEncoding["$"]  = "%24"
    UrlEncoding["%"]  = "%25"
    UrlEncoding["&"]  = "%26"
    UrlEncoding["'"]  = "%27"
    UrlEncoding["("]  = "%28"
    UrlEncoding[")"]  = "%29"
    UrlEncoding["*"]  = "%2A"
    UrlEncoding["+"]  = "%2B"
    UrlEncoding[","]  = "%2C"
    UrlEncoding["-"]  = "%2D"
    UrlEncoding["."]  = "%2E"
    UrlEncoding["/"]  = "%2F"
    UrlEncoding[":"]  = "%3A"
    UrlEncoding[";"]  = "%3B"
    UrlEncoding["<"]  = "%3C"
    UrlEncoding["="]  = "%3D"
    UrlEncoding[">"]  = "%3E"
    UrlEncoding["?"]  = "%3F"
    UrlEncoding["@"]  = "%40"
    UrlEncoding["["]  = "%5B"
    UrlEncoding["\\"] = "%5C"
    UrlEncoding["]"]  = "%5D"
    UrlEncoding["^"]  = "%5E"
    UrlEncoding["_"]  = "%5F"
    UrlEncoding["`"]  = "%60"
    UrlEncoding["{"]  = "%7B"
    UrlEncoding["|"]  = "%7C"
    UrlEncoding["}"]  = "%7D"
    UrlEncoding["~"]  = "%7E"
}
function escapeChar(char) {
    switch (char) {
    case "b":
        return "\b"
    case "f":
        return "\f"
    case "n":
        return "\n"
    case "r":
        return "\r"
    case "t":
        return "\t"
    case "v":
        return "\v"
    default:
        return char
    }
}
function literal(string,
                 c, escaping, i, s) {
    if (string !~ /^".*"$/)
        return string
    split(string, s, "")
    string = ""
    escaping = 0
    for (i = 2; i < length(s); i++) {
        c = s[i]
        if (escaping) {
            string = string escapeChar(c)
            escaping = 0
        } else {
            if (c == "\\")
                escaping = 1
            else
                string = string c
        }
    }
    return string
}
function escape(string) {
    gsub(/"/, "\\\"", string)
    gsub(/\\/, "\\\\", string)
    return string
}
function parameterize(string, quotationMark) {
    if (!quotationMark)
        quotationMark = "'"
    if (quotationMark == "'") {
        gsub(/'/, "'\\''", string)
        return "'" string "'"
    } else {
        return "\"" escape(string) "\""
    }
}
function quote(string,    i, r, s) {
    r = ""
    split(string, s, "")
    for (i = 1; i <= length(s); i++)
        r = r (s[i] in UrlEncoding ? UrlEncoding[s[i]] : s[i])
    return r
}
function replicate(string, len,
                   i, temp) {
    temp = ""
    for (i = 0; i < len; i++)
        temp = temp string
    return temp
}
function squeeze(line, preserveIndent) {
    if (!preserveIndent)
        gsub(/^[[:space:]]+/, "", line)
    gsub(/^[[:space:]]*#.*$/, "", line)
    gsub(/#[^"]*$/, "", line)
    gsub(/[[:space:]]+$/, "", line)
    gsub(/[[:space:]]+\\$/, "\\", line)
    return line
}
function anything(array,
                  i) {
    for (i in array)
        if (array[i]) return 1
    return 0
}
function append(array, element) {
    array[anything(array) ? length(array) : 0] = element
}
function belongsTo(element, array,
                   i) {
    for (i in array)
        if (element == array[i]) return element
    return ""
}
function startsWithAny(string, substrings,
                       i) {
    for (i in substrings)
        if (index(string, substrings[i]) == 1) return substrings[i]
    return ""
}
function matchesAny(string, patterns,
                    i) {
    for (i in patterns)
        if (string ~ "^" patterns[i]) return patterns[i]
    return ""
}
function join(array, separator, sortedIn, preserveNull,
              i, j, saveSortedIn, temp) {
    if (!separator)
        separator = " "
    if (!sortedIn)
        sortedIn = "@ind_num_asc"
    temp = ""
    j = 0
    saveSortedIn = PROCINFO["sorted_in"]
    if (length(array)) {
        PROCINFO["sorted_in"] = sortedIn
        for (i in array)
            if (preserveNull || array[i] != "")
                temp = j++ ? temp separator array[i] : array[i]
        PROCINFO["sorted_in"] = saveSortedIn
    } else
        temp = array
    return temp
}
function yn(string) {
    return (tolower(string) ~ /^[0fn]/) ? 0 : 1
}
function initAnsiCode() {
    if (ENVIRON["TERM"] == "dumb") return
    AnsiCode["reset"]         = AnsiCode[0] = "\33[0m"
    AnsiCode["bold"]          = "\33[1m"
    AnsiCode["underline"]     = "\33[4m"
    AnsiCode["negative"]      = "\33[7m"
    AnsiCode["no bold"]       = "\33[22m"
    AnsiCode["no underline"]  = "\33[24m"
    AnsiCode["positive"]      = "\33[27m"
    AnsiCode["black"]         = "\33[30m"
    AnsiCode["red"]           = "\33[31m"
    AnsiCode["green"]         = "\33[32m"
    AnsiCode["yellow"]        = "\33[33m"
    AnsiCode["blue"]          = "\33[34m"
    AnsiCode["magenta"]       = "\33[35m"
    AnsiCode["cyan"]          = "\33[36m"
    AnsiCode["gray"]          = "\33[37m"
    AnsiCode["default"]       = "\33[39m"
    AnsiCode["dark gray"]     = "\33[90m"
    AnsiCode["light red"]     = "\33[91m"
    AnsiCode["light green"]   = "\33[92m"
    AnsiCode["light yellow"]  = "\33[93m"
    AnsiCode["light blue"]    = "\33[94m"
    AnsiCode["light magenta"] = "\33[95m"
    AnsiCode["light cyan"]    = "\33[96m"
    AnsiCode["white"]         = "\33[97m"
}
function ansi(code, text) {
    switch (code) {
    case "bold":
        return AnsiCode[code] text AnsiCode["no bold"]
    case "underline":
        return AnsiCode[code] text AnsiCode["no underline"]
    case "negative":
        return AnsiCode[code] text AnsiCode["positive"]
    default:
        return AnsiCode[code] text AnsiCode[0]
    }
}
function w(text) {
    print ansi("yellow", text) > STDERR
}
function e(text) {
    print ansi("bold", ansi("red", text)) > STDERR
}
function d(text) {
    print ansi("gray", text) > STDERR
}
function da(array, formatString, sortedIn,
            i, j, saveSortedIn) {
    if (!formatString)
        formatString = "_[%s]='%s'"
    if (!sortedIn)
        sortedIn = "@ind_num_asc"
    saveSortedIn = PROCINFO["sorted_in"]
    PROCINFO["sorted_in"] = sortedIn
    for (i in array) {
        split(i, j, SUBSEP)
        d(sprintf(formatString, join(j, ","), array[i]))
    }
    PROCINFO["sorted_in"] = saveSortedIn
}
function assert(x, message) {
    if (!message)
        message = "[ERROR] Assertion failed."
    if (x)
        return x
    else
        e(message)
}
function fileExists(file) {
    return !system("test -f " file)
}
function initUriSchemes() {
    UriSchemes[0] = "file://"
    UriSchemes[1] = "http://"
    UriSchemes[2] = "https://"
}
BEGIN {
    initConst()
    initUrlEncoding()
    initAnsiCode()
    initUriSchemes()
}

function initLocale() {
    Locale["af"]["name"]               = "Afrikaans"
    Locale["af"]["endonym"]            = "Afrikaans"
    Locale["af"]["translations-of"]    = "Vertalings van %s"
    Locale["af"]["definitions-of"]     = "Definisies van %s"
    Locale["af"]["synonyms"]           = "Sinonieme"
    Locale["af"]["examples"]           = "Voorbeelde"
    Locale["af"]["see-also"]           = "Sien ook"
    Locale["af"]["family"]             = "Indo-European"
    Locale["af"]["iso"]                = "afr"
    Locale["af"]["glotto"]             = "afri1274"
    Locale["af"]["script"]             = "Latn"
    Locale["sq"]["name"]               = "Albanian"
    Locale["sq"]["endonym"]            = "Shqip"
    Locale["sq"]["translations-of"]    = "Përkthimet e %s"
    Locale["sq"]["definitions-of"]     = "Përkufizime të %s"
    Locale["sq"]["synonyms"]           = "Sinonime"
    Locale["sq"]["examples"]           = "Shembuj"
    Locale["sq"]["see-also"]           = "Shihni gjithashtu"
    Locale["sq"]["family"]             = "Indo-European"
    Locale["sq"]["iso"]                = "sqi"
    Locale["sq"]["glotto"]             = "alba1267"
    Locale["sq"]["script"]             = "Latn"
    Locale["ar"]["name"]               = "Arabic"
    Locale["ar"]["endonym"]            = "العربية"
    Locale["ar"]["translations-of"]    = "ترجمات %s"
    Locale["ar"]["definitions-of"]     = "تعريفات %s"
    Locale["ar"]["synonyms"]           = "مرادفات"
    Locale["ar"]["examples"]           = "أمثلة"
    Locale["ar"]["see-also"]           = "انظر أيضًا"
    Locale["ar"]["family"]             = "Afro-Asiatic"
    Locale["ar"]["iso"]                = "ara"
    Locale["ar"]["glotto"]             = "arab1395"
    Locale["ar"]["script"]             = "Arab"
    Locale["ar"]["rtl"]                = "true"
    Locale["hy"]["name"]               = "Armenian"
    Locale["hy"]["endonym"]            = "Հայերեն"
    Locale["hy"]["translations-of"]    = "%s-ի թարգմանությունները"
    Locale["hy"]["definitions-of"]     = "%s-ի սահմանումները"
    Locale["hy"]["synonyms"]           = "Հոմանիշներ"
    Locale["hy"]["examples"]           = "Օրինակներ"
    Locale["hy"]["see-also"]           = "Տես նաև"
    Locale["hy"]["family"]             = "Indo-European"
    Locale["hy"]["iso"]                = "hye"
    Locale["hy"]["glotto"]             = "arme1241"
    Locale["hy"]["script"]             = "Armn"
    Locale["az"]["name"]               = "Azerbaijani"
    Locale["az"]["endonym"]            = "Azərbaycanca"
    Locale["az"]["translations-of"]    = "%s sözünün tərcüməsi"
    Locale["az"]["definitions-of"]     = "%s sözünün tərifləri"
    Locale["az"]["synonyms"]           = "Sinonimlər"
    Locale["az"]["examples"]           = "Nümunələr"
    Locale["az"]["see-also"]           = "Həmçinin, baxın:"
    Locale["az"]["family"]             = "Turkic"
    Locale["az"]["iso"]                = "aze"
    Locale["az"]["glotto"]             = "azer1255"
    Locale["az"]["script"]             = "Latn"
    Locale["eu"]["name"]               = "Basque"
    Locale["eu"]["endonym"]            = "Euskara"
    Locale["eu"]["translations-of"]    = "%s esapidearen itzulpena"
    Locale["eu"]["definitions-of"]     = "Honen definizioak: %s"
    Locale["eu"]["synonyms"]           = "Sinonimoak"
    Locale["eu"]["examples"]           = "Adibideak"
    Locale["eu"]["see-also"]           = "Ikusi hauek ere"
    Locale["eu"]["iso"]                = "eus"
    Locale["eu"]["glotto"]             = "basq1248"
    Locale["eu"]["script"]             = "Latn"
    Locale["be"]["name"]               = "Belarusian"
    Locale["be"]["endonym"]            = "беларуская"
    Locale["be"]["translations-of"]    = "Пераклады %s"
    Locale["be"]["definitions-of"]     = "Вызначэннi %s"
    Locale["be"]["synonyms"]           = "Сінонімы"
    Locale["be"]["examples"]           = "Прыклады"
    Locale["be"]["see-also"]           = "Гл. таксама"
    Locale["be"]["family"]             = "Indo-European"
    Locale["be"]["iso"]                = "bel"
    Locale["be"]["glotto"]             = "bela1254"
    Locale["be"]["script"]             = "Cyrl"
    Locale["bn"]["name"]               = "Bengali"
    Locale["bn"]["endonym"]            = "বাংলা"
    Locale["bn"]["translations-of"]    = "%s এর অনুবাদ"
    Locale["bn"]["definitions-of"]     = "%s এর সংজ্ঞা"
    Locale["bn"]["synonyms"]           = "প্রতিশব্দ"
    Locale["bn"]["examples"]           = "উদাহরণ"
    Locale["bn"]["see-also"]           = "আরো দেখুন"
    Locale["bn"]["family"]             = "Indo-European"
    Locale["bn"]["iso"]                = "ben"
    Locale["bn"]["glotto"]             = "beng1280"
    Locale["bn"]["script"]             = "Beng"
    Locale["bs"]["name"]               = "Bosnian"
    Locale["bs"]["endonym"]            = "Bosanski"
    Locale["bs"]["translations-of"]    = "Prijevod za: %s"
    Locale["bs"]["definitions-of"]     = "Definicije za %s"
    Locale["bs"]["synonyms"]           = "Sinonimi"
    Locale["bs"]["examples"]           = "Primjeri"
    Locale["bs"]["see-also"]           = "Pogledajte i"
    Locale["bs"]["family"]             = "Indo-European"
    Locale["bs"]["iso"]                = "bos"
    Locale["bs"]["glotto"]             = "bosn1245"
    Locale["bs"]["script"]             = "Latn"
    Locale["bg"]["name"]               = "Bulgarian"
    Locale["bg"]["endonym"]            = "български"
    Locale["bg"]["translations-of"]    = "Преводи на %s"
    Locale["bg"]["definitions-of"]     = "Дефиниции за %s"
    Locale["bg"]["synonyms"]           = "Синоними"
    Locale["bg"]["examples"]           = "Примери"
    Locale["bg"]["see-also"]           = "Вижте също"
    Locale["bg"]["family"]             = "Indo-European"
    Locale["bg"]["iso"]                = "bul"
    Locale["bg"]["glotto"]             = "bulg1262"
    Locale["bg"]["script"]             = "Cyrl"
    Locale["ca"]["name"]               = "Catalan"
    Locale["ca"]["endonym"]            = "Català"
    Locale["ca"]["translations-of"]    = "Traduccions per a %s"
    Locale["ca"]["definitions-of"]     = "Definicions de: %s"
    Locale["ca"]["synonyms"]           = "Sinònims"
    Locale["ca"]["examples"]           = "Exemples"
    Locale["ca"]["see-also"]           = "Vegeu també"
    Locale["ca"]["family"]             = "Indo-European"
    Locale["ca"]["iso"]                = "cat"
    Locale["ca"]["glotto"]             = "stan1289"
    Locale["ca"]["script"]             = "Latn"
    Locale["ceb"]["name"]              = "Cebuano"
    Locale["ceb"]["endonym"]           = "Cebuano"
    Locale["ceb"]["translations-of"]   = "%s Mga Paghubad sa PULONG_O_HUGPONG SA PAMULONG"
    Locale["ceb"]["definitions-of"]    = "Mga kahulugan sa %s"
    Locale["ceb"]["synonyms"]          = "Mga Kapulong"
    Locale["ceb"]["examples"]          = "Mga pananglitan:"
    Locale["ceb"]["see-also"]          = "Kitaa pag-usab"
    Locale["ceb"]["family"]            = "Austronesian"
    Locale["ceb"]["iso"]               = "ceb"
    Locale["ceb"]["glotto"]            = "cebu1242"
    Locale["ceb"]["script"]            = "Latn"
    Locale["ny"]["name"]               = "Chichewa"
    Locale["ny"]["endonym"]            = "Nyanja"
    Locale["ny"]["translations-of"]    = "Matanthauzidwe a %s"
    Locale["ny"]["definitions-of"]     = "Mamasulidwe a %s"
    Locale["ny"]["synonyms"]           = "Mau ofanana"
    Locale["ny"]["examples"]           = "Zitsanzo"
    Locale["ny"]["see-also"]           = "Onaninso"
    Locale["ny"]["family"]             = "Atlantic-Congo"
    Locale["ny"]["iso"]                = "nya"
    Locale["ny"]["glotto"]             = "nyan1308"
    Locale["ny"]["script"]             = "Latn"
    Locale["zh-CN"]["name"]            = "Chinese Simplified"
    Locale["zh-CN"]["endonym"]         = "简体中文"
    Locale["zh-CN"]["translations-of"] = "%s 的翻译"
    Locale["zh-CN"]["definitions-of"]  = "%s的定义"
    Locale["zh-CN"]["synonyms"]        = "同义词"
    Locale["zh-CN"]["examples"]        = "示例"
    Locale["zh-CN"]["see-also"]        = "另请参阅"
    Locale["zh-CN"]["family"]          = "Sino-Tibetan"
    Locale["zh-CN"]["iso"]             = "zho"
    Locale["zh-CN"]["glotto"]          = "mand1415"
    Locale["zh-CN"]["script"]          = "Hans"
    Locale["zh-TW"]["name"]            = "Chinese Traditional"
    Locale["zh-TW"]["endonym"]         = "正體中文"
    Locale["zh-TW"]["translations-of"] = "「%s」的翻譯"
    Locale["zh-TW"]["definitions-of"]  = "「%s」的定義"
    Locale["zh-TW"]["synonyms"]        = "同義詞"
    Locale["zh-TW"]["examples"]        = "例句"
    Locale["zh-TW"]["see-also"]        = "另請參閱"
    Locale["zh-TW"]["family"]          = "Sino-Tibetan"
    Locale["zh-TW"]["iso"]             = "zho"
    Locale["zh-TW"]["glotto"]          = "mand1415"
    Locale["zh-TW"]["script"]          = "Hant"
    Locale["hr"]["name"]               = "Croatian"
    Locale["hr"]["endonym"]            = "Hrvatski"
    Locale["hr"]["translations-of"]    = "Prijevodi riječi ili izraza %s"
    Locale["hr"]["definitions-of"]     = "Definicije riječi ili izraza %s"
    Locale["hr"]["synonyms"]           = "Sinonimi"
    Locale["hr"]["examples"]           = "Primjeri"
    Locale["hr"]["see-also"]           = "Također pogledajte"
    Locale["hr"]["family"]             = "Indo-European"
    Locale["hr"]["iso"]                = "hrv"
    Locale["hr"]["glotto"]             = "croa1245"
    Locale["hr"]["script"]             = "Latn"
    Locale["cs"]["name"]               = "Czech"
    Locale["cs"]["endonym"]            = "Čeština"
    Locale["cs"]["translations-of"]    = "Překlad výrazu %s"
    Locale["cs"]["definitions-of"]     = "Definice výrazu %s"
    Locale["cs"]["synonyms"]           = "Synonyma"
    Locale["cs"]["examples"]           = "Příklady"
    Locale["cs"]["see-also"]           = "Viz také"
    Locale["cs"]["family"]             = "Indo-European"
    Locale["cs"]["iso"]                = "ces"
    Locale["cs"]["glotto"]             = "czec1258"
    Locale["cs"]["script"]             = "Latn"
    Locale["da"]["name"]               = "Danish"
    Locale["da"]["endonym"]            = "Dansk"
    Locale["da"]["translations-of"]    = "Oversættelser af %s"
    Locale["da"]["definitions-of"]     = "Definitioner af %s"
    Locale["da"]["synonyms"]           = "Synonymer"
    Locale["da"]["examples"]           = "Eksempler"
    Locale["da"]["see-also"]           = "Se også"
    Locale["da"]["family"]             = "Indo-European"
    Locale["da"]["iso"]                = "dan"
    Locale["da"]["glotto"]             = "dani1285"
    Locale["da"]["script"]             = "Latn"
    Locale["nl"]["name"]               = "Dutch"
    Locale["nl"]["endonym"]            = "Nederlands"
    Locale["nl"]["translations-of"]    = "Vertalingen van %s"
    Locale["nl"]["definitions-of"]     = "Definities van %s"
    Locale["nl"]["synonyms"]           = "Synoniemen"
    Locale["nl"]["examples"]           = "Voorbeelden"
    Locale["nl"]["see-also"]           = "Zie ook"
    Locale["nl"]["family"]             = "Indo-European"
    Locale["nl"]["iso"]                = "nld"
    Locale["nl"]["glotto"]             = "dutc1256"
    Locale["nl"]["script"]             = "Latn"
    Locale["en"]["name"]               = "English"
    Locale["en"]["endonym"]            = "English"
    Locale["en"]["translations-of"]    = "Translations of %s"
    Locale["en"]["definitions-of"]     = "Definitions of %s"
    Locale["en"]["synonyms"]           = "Synonyms"
    Locale["en"]["examples"]           = "Examples"
    Locale["en"]["see-also"]           = "See also"
    Locale["en"]["family"]             = "Indo-European"
    Locale["en"]["iso"]                = "eng"
    Locale["en"]["glotto"]             = "stan1293"
    Locale["en"]["script"]             = "Latn"
    Locale["eo"]["name"]               = "Esperanto"
    Locale["eo"]["endonym"]            = "Esperanto"
    Locale["eo"]["translations-of"]    = "Tradukoj de %s"
    Locale["eo"]["definitions-of"]     = "Difinoj de %s"
    Locale["eo"]["synonyms"]           = "Sinonimoj"
    Locale["eo"]["examples"]           = "Ekzemploj"
    Locale["eo"]["see-also"]           = "Vidu ankaŭ"
    Locale["eo"]["family"]             = "Artificial Language"
    Locale["eo"]["iso"]                = "epo"
    Locale["eo"]["glotto"]             = "espe1235"
    Locale["eo"]["script"]             = "Latn"
    Locale["et"]["name"]               = "Estonian"
    Locale["et"]["endonym"]            = "Eesti"
    Locale["et"]["translations-of"]    = "Sõna(de) %s tõlked"
    Locale["et"]["definitions-of"]     = "Sõna(de) %s definitsioonid"
    Locale["et"]["synonyms"]           = "Sünonüümid"
    Locale["et"]["examples"]           = "Näited"
    Locale["et"]["see-also"]           = "Vt ka"
    Locale["et"]["family"]             = "Uralic"
    Locale["et"]["iso"]                = "est"
    Locale["et"]["glotto"]             = "esto1258"
    Locale["et"]["script"]             = "Latn"
    Locale["tl"]["name"]               = "Filipino"
    Locale["tl"]["endonym"]            = "Tagalog"
    Locale["tl"]["translations-of"]    = "Mga pagsasalin ng %s"
    Locale["tl"]["definitions-of"]     = "Mga kahulugan ng %s"
    Locale["tl"]["synonyms"]           = "Mga Kasingkahulugan"
    Locale["tl"]["examples"]           = "Mga Halimbawa"
    Locale["tl"]["see-also"]           = "Tingnan rin ang"
    Locale["tl"]["family"]             = "Austronesian"
    Locale["tl"]["iso"]                = "tgl"
    Locale["tl"]["glotto"]             = "taga1270"
    Locale["tl"]["script"]             = "Latn"
    Locale["fi"]["name"]               = "Finnish"
    Locale["fi"]["endonym"]            = "Suomi"
    Locale["fi"]["translations-of"]    = "Käännökset tekstille %s"
    Locale["fi"]["definitions-of"]     = "Määritelmät kohteelle %s"
    Locale["fi"]["synonyms"]           = "Synonyymit"
    Locale["fi"]["examples"]           = "Esimerkkejä"
    Locale["fi"]["see-also"]           = "Katso myös"
    Locale["fi"]["family"]             = "Uralic"
    Locale["fi"]["iso"]                = "fin"
    Locale["fi"]["glotto"]             = "finn1318"
    Locale["fi"]["script"]             = "Latn"
    Locale["fr"]["name"]               = "French"
    Locale["fr"]["endonym"]            = "Français"
    Locale["fr"]["translations-of"]    = "Traductions de %s"
    Locale["fr"]["definitions-of"]     = "Définitions de %s"
    Locale["fr"]["synonyms"]           = "Synonymes"
    Locale["fr"]["examples"]           = "Exemples"
    Locale["fr"]["see-also"]           = "Voir aussi"
    Locale["fr"]["family"]             = "Indo-European"
    Locale["fr"]["iso"]                = "fra"
    Locale["fr"]["glotto"]             = "stan1290"
    Locale["fr"]["script"]             = "Latn"
    Locale["gl"]["name"]               = "Galician"
    Locale["gl"]["endonym"]            = "Galego"
    Locale["gl"]["translations-of"]    = "Traducións de %s"
    Locale["gl"]["definitions-of"]     = "Definicións de %s"
    Locale["gl"]["synonyms"]           = "Sinónimos"
    Locale["gl"]["examples"]           = "Exemplos"
    Locale["gl"]["see-also"]           = "Ver tamén"
    Locale["gl"]["family"]             = "Indo-European"
    Locale["gl"]["iso"]                = "glg"
    Locale["gl"]["glotto"]             = "gali1258"
    Locale["gl"]["script"]             = "Latn"
    Locale["ka"]["name"]               = "Georgian"
    Locale["ka"]["endonym"]            = "ქართული"
    Locale["ka"]["translations-of"]    = "%s-ის თარგმანები"
    Locale["ka"]["definitions-of"]     = "%s-ის განსაზღვრებები"
    Locale["ka"]["synonyms"]           = "სინონიმები"
    Locale["ka"]["examples"]           = "მაგალითები"
    Locale["ka"]["see-also"]           = "ასევე იხილეთ"
    Locale["ka"]["family"]             = "Kartvelian"
    Locale["ka"]["iso"]                = "kat"
    Locale["ka"]["glotto"]             = "nucl1302"
    Locale["ka"]["script"]             = "Geor"
    Locale["de"]["name"]               = "German"
    Locale["de"]["endonym"]            = "Deutsch"
    Locale["de"]["translations-of"]    = "Übersetzungen für %s"
    Locale["de"]["definitions-of"]     = "Definitionen von %s"
    Locale["de"]["synonyms"]           = "Synonyme"
    Locale["de"]["examples"]           = "Beispiele"
    Locale["de"]["see-also"]           = "Siehe auch"
    Locale["de"]["family"]             = "Indo-European"
    Locale["de"]["iso"]                = "stan1295"
    Locale["de"]["glotto"]             = "deu"
    Locale["de"]["script"]             = "Latn"
    Locale["el"]["name"]               = "Greek"
    Locale["el"]["endonym"]            = "Ελληνικά"
    Locale["el"]["translations-of"]    = "Μεταφράσεις του %s"
    Locale["el"]["definitions-of"]     = "Όρισμοί %s"
    Locale["el"]["synonyms"]           = "Συνώνυμα"
    Locale["el"]["examples"]           = "Παραδείγματα"
    Locale["el"]["see-also"]           = "Δείτε επίσης"
    Locale["el"]["family"]             = "Indo-European"
    Locale["el"]["iso"]                = "ell"
    Locale["el"]["glotto"]             = "mode1248"
    Locale["el"]["script"]             = "Grek"
    Locale["gu"]["name"]               = "Gujarati"
    Locale["gu"]["endonym"]            = "ગુજરાતી"
    Locale["gu"]["translations-of"]    = "%s ના અનુવાદ"
    Locale["gu"]["definitions-of"]     = "%s ની વ્યાખ્યાઓ"
    Locale["gu"]["synonyms"]           = "સમાનાર્થી"
    Locale["gu"]["examples"]           = "ઉદાહરણો"
    Locale["gu"]["see-also"]           = "આ પણ જુઓ"
    Locale["gu"]["family"]             = "Indo-European"
    Locale["gu"]["iso"]                = "guj"
    Locale["gu"]["glotto"]             = "guja1252"
    Locale["gu"]["script"]             = "Gujr"
    Locale["ht"]["name"]               = "Haitian Creole"
    Locale["ht"]["endonym"]            = "Kreyòl Ayisyen"
    Locale["ht"]["translations-of"]    = "Tradiksyon %s"
    Locale["ht"]["definitions-of"]     = "Definisyon nan %s"
    Locale["ht"]["synonyms"]           = "Sinonim"
    Locale["ht"]["examples"]           = "Egzanp:"
    Locale["ht"]["see-also"]           = "Wè tou"
    Locale["ht"]["family"]             = "Indo-European"
    Locale["ht"]["iso"]                = "hat"
    Locale["ht"]["glotto"]             = "hait1244"
    Locale["ht"]["script"]             = "Latn"
    Locale["ha"]["name"]               = "Hausa"
    Locale["ha"]["endonym"]            = "Hausa"
    Locale["ha"]["translations-of"]    = "Fassarar %s"
    Locale["ha"]["definitions-of"]     = "Ma'anoni na %s"
    Locale["ha"]["synonyms"]           = "Masu kamancin ma'ana"
    Locale["ha"]["examples"]           = "Misalai"
    Locale["ha"]["see-also"]           = "Duba kuma"
    Locale["ha"]["family"]             = "Afro-Asiatic"
    Locale["ha"]["iso"]                = "hau"
    Locale["ha"]["glotto"]             = "haus1257"
    Locale["ha"]["script"]             = "Latn"
    Locale["he"]["name"]               = "Hebrew"
    Locale["he"]["endonym"]            = "עִבְרִית"
    Locale["he"]["translations-of"]    = "תרגומים של %s"
    Locale["he"]["definitions-of"]     = "הגדרות של %s"
    Locale["he"]["synonyms"]           = "מילים נרדפות"
    Locale["he"]["examples"]           = "דוגמאות"
    Locale["he"]["see-also"]           = "ראה גם"
    Locale["he"]["family"]             = "Afro-Asiatic"
    Locale["he"]["iso"]                = "heb"
    Locale["he"]["glotto"]             = "hebr1245"
    Locale["he"]["script"]             = "Hebr"
    Locale["he"]["rtl"]                = "true"
    Locale["hi"]["name"]               = "Hindi"
    Locale["hi"]["endonym"]            = "हिन्दी"
    Locale["hi"]["translations-of"]    = "%s के अनुवाद"
    Locale["hi"]["definitions-of"]     = "%s की परिभाषाएं"
    Locale["hi"]["synonyms"]           = "समानार्थी"
    Locale["hi"]["examples"]           = "उदाहरण"
    Locale["hi"]["see-also"]           = "यह भी देखें"
    Locale["hi"]["family"]             = "Indo-European"
    Locale["hi"]["iso"]                = "hin"
    Locale["hi"]["glotto"]             = "hind1269"
    Locale["hi"]["script"]             = "Deva"
    Locale["hmn"]["name"]              = "Hmong"
    Locale["hmn"]["endonym"]           = "Hmoob"
    Locale["hmn"]["translations-of"]   = "Lus txhais: %s"
    Locale["hmn"]["family"]            = "Hmong-Mien"
    Locale["hmn"]["iso"]               = "hmn"
    Locale["hmn"]["glotto"]            = "firs1234"
    Locale["hmn"]["script"]            = "Latn"
    Locale["hu"]["name"]               = "Hungarian"
    Locale["hu"]["endonym"]            = "Magyar"
    Locale["hu"]["translations-of"]    = "%s fordításai"
    Locale["hu"]["definitions-of"]     = "%s jelentései"
    Locale["hu"]["synonyms"]           = "Szinonimák"
    Locale["hu"]["examples"]           = "Példák"
    Locale["hu"]["see-also"]           = "Lásd még"
    Locale["hu"]["family"]             = "Uralic"
    Locale["hu"]["iso"]                = "hun"
    Locale["hu"]["glotto"]             = "hung1274"
    Locale["hu"]["script"]             = "Latn"
    Locale["is"]["name"]               = "Icelandic"
    Locale["is"]["endonym"]            = "Íslenska"
    Locale["is"]["translations-of"]    = "Þýðingar á %s"
    Locale["is"]["definitions-of"]     = "Skilgreiningar á"
    Locale["is"]["synonyms"]           = "Samheiti"
    Locale["is"]["examples"]           = "Dæmi"
    Locale["is"]["see-also"]           = "Sjá einnig"
    Locale["is"]["family"]             = "Indo-European"
    Locale["is"]["iso"]                = "isl"
    Locale["is"]["glotto"]             = "icel1247"
    Locale["is"]["script"]             = "Latn"
    Locale["ig"]["name"]               = "Igbo"
    Locale["ig"]["endonym"]            = "Igbo"
    Locale["ig"]["translations-of"]    = "Ntụgharị asụsụ nke %s"
    Locale["ig"]["definitions-of"]     = "Nkọwapụta nke %s"
    Locale["ig"]["synonyms"]           = "Okwu oyiri"
    Locale["ig"]["examples"]           = "Ọmụmaatụ"
    Locale["ig"]["see-also"]           = "Hụkwuo"
    Locale["ig"]["family"]             = "Atlantic-Congo"
    Locale["ig"]["iso"]                = "ibo"
    Locale["ig"]["glotto"]             = "igbo1259"
    Locale["ig"]["script"]             = "Latn"
    Locale["id"]["name"]               = "Indonesian"
    Locale["id"]["endonym"]            = "Bahasa Indonesia"
    Locale["id"]["translations-of"]    = "Terjemahan dari %s"
    Locale["id"]["definitions-of"]     = "Definisi %s"
    Locale["id"]["synonyms"]           = "Sinonim"
    Locale["id"]["examples"]           = "Contoh"
    Locale["id"]["see-also"]           = "Lihat juga"
    Locale["id"]["family"]             = "Austronesian"
    Locale["id"]["iso"]                = "ind"
    Locale["id"]["glotto"]             = "indo1316"
    Locale["id"]["script"]             = "Latn"
    Locale["ga"]["name"]               = "Irish"
    Locale["ga"]["endonym"]            = "Gaeilge"
    Locale["ga"]["translations-of"]    = "Aistriúcháin ar %s"
    Locale["ga"]["definitions-of"]     = "Sainmhínithe ar %s"
    Locale["ga"]["synonyms"]           = "Comhchiallaigh"
    Locale["ga"]["examples"]           = "Samplaí"
    Locale["ga"]["see-also"]           = "féach freisin"
    Locale["ga"]["family"]             = "Indo-European"
    Locale["ga"]["iso"]                = "gle"
    Locale["ga"]["glotto"]             = "iris1253"
    Locale["ga"]["script"]             = "Latn"
    Locale["it"]["name"]               = "Italian"
    Locale["it"]["endonym"]            = "Italiano"
    Locale["it"]["translations-of"]    = "Traduzioni di %s"
    Locale["it"]["definitions-of"]     = "Definizioni di %s"
    Locale["it"]["synonyms"]           = "Sinonimi"
    Locale["it"]["examples"]           = "Esempi"
    Locale["it"]["see-also"]           = "Vedi anche"
    Locale["it"]["family"]             = "Indo-European"
    Locale["it"]["iso"]                = "ita"
    Locale["it"]["glotto"]             = "ital1282"
    Locale["it"]["script"]             = "Latn"
    Locale["ja"]["name"]               = "Japanese"
    Locale["ja"]["endonym"]            = "日本語"
    Locale["ja"]["translations-of"]    = "「%s」の翻訳"
    Locale["ja"]["definitions-of"]     = "%s の定義"
    Locale["ja"]["synonyms"]           = "同義語"
    Locale["ja"]["examples"]           = "例"
    Locale["ja"]["see-also"]           = "関連項目"
    Locale["ja"]["family"]             = "Japonic"
    Locale["ja"]["iso"]                = "jpn"
    Locale["ja"]["glotto"]             = "japa1256"
    Locale["ja"]["script"]             = "Jpan"
    Locale["jv"]["name"]               = "Javanese"
    Locale["jv"]["endonym"]            = "Basa Jawa"
    Locale["jv"]["translations-of"]    = "Terjemahan %s"
    Locale["jv"]["definitions-of"]     = "Arti %s"
    Locale["jv"]["synonyms"]           = "Sinonim"
    Locale["jv"]["examples"]           = "Conto"
    Locale["jv"]["see-also"]           = "Deleng uga"
    Locale["jv"]["family"]             = "Austronesian"
    Locale["jv"]["iso"]                = "jav"
    Locale["jv"]["glotto"]             = "java1254"
    Locale["jv"]["script"]             = "Latn"
    Locale["kn"]["name"]               = "Kannada"
    Locale["kn"]["endonym"]            = "ಕನ್ನಡ"
    Locale["kn"]["translations-of"]    = "%s ನ ಅನುವಾದಗಳು"
    Locale["kn"]["definitions-of"]     = "%s ನ ವ್ಯಾಖ್ಯಾನಗಳು"
    Locale["kn"]["synonyms"]           = "ಸಮಾನಾರ್ಥಕಗಳು"
    Locale["kn"]["examples"]           = "ಉದಾಹರಣೆಗಳು"
    Locale["kn"]["see-also"]           = "ಇದನ್ನೂ ಗಮನಿಸಿ"
    Locale["kn"]["family"]             = "Dravidian"
    Locale["kn"]["iso"]                = "kan"
    Locale["kn"]["glotto"]             = "kann1255"
    Locale["kn"]["script"]             = "Knda"
    Locale["kk"]["name"]               = "Kazakh"
    Locale["kk"]["endonym"]            = "Қазақ тілі"
    Locale["kk"]["translations-of"]    = "%s аудармалары"
    Locale["kk"]["definitions-of"]     = "%s анықтамалары"
    Locale["kk"]["synonyms"]           = "Синонимдер"
    Locale["kk"]["examples"]           = "Мысалдар"
    Locale["kk"]["see-also"]           = "Келесі тізімді де көріңіз:"
    Locale["kk"]["family"]             = "Turkic"
    Locale["kk"]["iso"]                = "kaz"
    Locale["kk"]["glotto"]             = "kaza1248"
    Locale["kk"]["script"]             = "Cyrl"
    Locale["km"]["name"]               = "Khmer"
    Locale["km"]["endonym"]            = "ភាសាខ្មែរ"
    Locale["km"]["translations-of"]    = "ការ​បក​ប្រែ​នៃ %s"
    Locale["km"]["definitions-of"]     = "និយមន័យ​នៃ​ %s"
    Locale["km"]["synonyms"]           = "សទិសន័យ"
    Locale["km"]["examples"]           = "ឧទាហរណ៍"
    Locale["km"]["see-also"]           = "មើល​ផង​ដែរ"
    Locale["km"]["family"]             = "Austroasiatic"
    Locale["km"]["iso"]                = "khm"
    Locale["km"]["glotto"]             = "cent1989"
    Locale["km"]["script"]             = "Khmr"
    Locale["ko"]["name"]               = "Korean"
    Locale["ko"]["endonym"]            = "한국어"
    Locale["ko"]["translations-of"]    = "%s의 번역"
    Locale["ko"]["definitions-of"]     = "%s의 정의"
    Locale["ko"]["synonyms"]           = "동의어"
    Locale["ko"]["examples"]           = "예문"
    Locale["ko"]["see-also"]           = "참조"
    Locale["ko"]["family"]             = "Koreanic"
    Locale["ko"]["iso"]                = "kor"
    Locale["ko"]["glotto"]             = "kore1280"
    Locale["ko"]["script"]             = "Kore"
    Locale["lo"]["name"]               = "Lao"
    Locale["lo"]["endonym"]            = "ລາວ"
    Locale["lo"]["translations-of"]    = "ຄຳ​ແປ​ສຳລັບ %s"
    Locale["lo"]["definitions-of"]     = "ຄວາມໝາຍຂອງ %s"
    Locale["lo"]["synonyms"]           = "ຄຳທີ່ຄ້າຍກັນ %s"
    Locale["lo"]["examples"]           = "ຕົວຢ່າງ"
    Locale["lo"]["see-also"]           = "ເບິ່ງ​ເພີ່ມ​ເຕີມ"
    Locale["lo"]["family"]             = "Tai-Kadai"
    Locale["lo"]["iso"]                = "lao"
    Locale["lo"]["glotto"]             = "laoo1244"
    Locale["lo"]["script"]             = "Laoo"
    Locale["la"]["name"]               = "Latin"
    Locale["la"]["endonym"]            = "Latina"
    Locale["la"]["translations-of"]    = "Versio de %s"
    Locale["la"]["family"]             = "Indo-European"
    Locale["la"]["iso"]                = "lat"
    Locale["la"]["glotto"]             = "lati1261"
    Locale["la"]["script"]             = "Latn"
    Locale["lv"]["name"]               = "Latvian"
    Locale["lv"]["endonym"]            = "Latviešu"
    Locale["lv"]["translations-of"]    = "%s tulkojumi"
    Locale["lv"]["definitions-of"]     = "%s definīcijas"
    Locale["lv"]["synonyms"]           = "Sinonīmi"
    Locale["lv"]["examples"]           = "Piemēri"
    Locale["lv"]["see-also"]           = "Skatiet arī"
    Locale["lv"]["family"]             = "Indo-European"
    Locale["lv"]["iso"]                = "lav"
    Locale["lv"]["glotto"]             = "latv1249"
    Locale["lv"]["script"]             = "Latn"
    Locale["lt"]["name"]               = "Lithuanian"
    Locale["lt"]["endonym"]            = "Lietuvių"
    Locale["lt"]["translations-of"]    = "„%s“ vertimai"
    Locale["lt"]["definitions-of"]     = "„%s“ apibrėžimai"
    Locale["lt"]["synonyms"]           = "Sinonimai"
    Locale["lt"]["examples"]           = "Pavyzdžiai"
    Locale["lt"]["see-also"]           = "Taip pat žiūrėkite"
    Locale["lt"]["family"]             = "Indo-European"
    Locale["lt"]["iso"]                = "lit"
    Locale["lt"]["glotto"]             = "lith1251"
    Locale["lt"]["script"]             = "Latn"
    Locale["mk"]["name"]               = "Macedonian"
    Locale["mk"]["endonym"]            = "Македонски"
    Locale["mk"]["translations-of"]    = "Преводи на %s"
    Locale["mk"]["definitions-of"]     = "Дефиниции на %s"
    Locale["mk"]["synonyms"]           = "Синоними"
    Locale["mk"]["examples"]           = "Примери"
    Locale["mk"]["see-also"]           = "Види и"
    Locale["mk"]["family"]             = "Indo-European"
    Locale["mk"]["iso"]                = "mkd"
    Locale["mk"]["glotto"]             = "mace1250"
    Locale["mk"]["script"]             = "Cyrl"
    Locale["mg"]["name"]               = "Malagasy"
    Locale["mg"]["endonym"]            = "Malagasy"
    Locale["mg"]["translations-of"]    = "Dikan'ny %s"
    Locale["mg"]["definitions-of"]     = "Famaritana ny %s"
    Locale["mg"]["synonyms"]           = "Mitovy hevitra"
    Locale["mg"]["examples"]           = "Ohatra"
    Locale["mg"]["see-also"]           = "Jereo ihany koa"
    Locale["mg"]["family"]             = "Austronesian"
    Locale["mg"]["iso"]                = "mlg"
    Locale["mg"]["glotto"]             = "plat1254"
    Locale["mg"]["script"]             = "Latn"
    Locale["ms"]["name"]               = "Malay"
    Locale["ms"]["endonym"]            = "Bahasa Melayu"
    Locale["ms"]["translations-of"]    = "Terjemahan %s"
    Locale["ms"]["definitions-of"]     = "Takrif %s"
    Locale["ms"]["synonyms"]           = "Sinonim"
    Locale["ms"]["examples"]           = "Contoh"
    Locale["ms"]["see-also"]           = "Lihat juga"
    Locale["ms"]["family"]             = "Austronesian"
    Locale["ms"]["iso"]                = "msa"
    Locale["ms"]["glotto"]             = "stan1306"
    Locale["ms"]["script"]             = "Latn"
    Locale["ml"]["name"]               = "Malayalam"
    Locale["ml"]["endonym"]            = "മലയാളം"
    Locale["ml"]["translations-of"]    = "%s എന്നതിന്റെ വിവർത്തനങ്ങൾ"
    Locale["ml"]["definitions-of"]     = "%s എന്നതിന്റെ നിർവ്വചനങ്ങൾ"
    Locale["ml"]["synonyms"]           = "പര്യായങ്ങള്‍"
    Locale["ml"]["examples"]           = "ഉദാഹരണങ്ങള്‍"
    Locale["ml"]["see-also"]           = "ഇതും കാണുക"
    Locale["ml"]["family"]             = "Dravidian"
    Locale["ml"]["iso"]                = "mal"
    Locale["ml"]["glotto"]             = "mala1464"
    Locale["ml"]["script"]             = "Mlym"
    Locale["mt"]["name"]               = "Maltese"
    Locale["mt"]["endonym"]            = "Malti"
    Locale["mt"]["translations-of"]    = "Traduzzjonijiet ta' %s"
    Locale["mt"]["definitions-of"]     = "Definizzjonijiet ta' %s"
    Locale["mt"]["synonyms"]           = "Sinonimi"
    Locale["mt"]["examples"]           = "Eżempji"
    Locale["mt"]["see-also"]           = "Ara wkoll"
    Locale["mt"]["family"]             = "Afro-Asiatic"
    Locale["mt"]["iso"]                = "mlt"
    Locale["mt"]["glotto"]             = "malt1254"
    Locale["mt"]["script"]             = "Latn"
    Locale["mi"]["name"]               = "Maori"
    Locale["mi"]["endonym"]            = "Māori"
    Locale["mi"]["translations-of"]    = "Ngā whakamāoritanga o %s"
    Locale["mi"]["definitions-of"]     = "Ngā whakamārama o %s"
    Locale["mi"]["synonyms"]           = "Ngā Kupu Taurite"
    Locale["mi"]["examples"]           = "Ngā Tauira:"
    Locale["mi"]["see-also"]           = "Tiro hoki:"
    Locale["mi"]["family"]             = "Austronesian"
    Locale["mi"]["iso"]                = "mri"
    Locale["mi"]["glotto"]             = "maor1246"
    Locale["mi"]["script"]             = "Latn"
    Locale["mr"]["name"]               = "Marathi"
    Locale["mr"]["endonym"]            = "मराठी"
    Locale["mr"]["translations-of"]    = "%s ची भाषांतरे"
    Locale["mr"]["definitions-of"]     = "%s च्या व्याख्या"
    Locale["mr"]["synonyms"]           = "समानार्थी शब्द"
    Locale["mr"]["examples"]           = "उदाहरणे"
    Locale["mr"]["see-also"]           = "हे देखील पहा"
    Locale["mr"]["family"]             = "Indo-European"
    Locale["mr"]["iso"]                = "mar"
    Locale["mr"]["glotto"]             = "mara1378"
    Locale["mr"]["script"]             = "Deva"
    Locale["mn"]["name"]               = "Mongolian"
    Locale["mn"]["endonym"]            = "Монгол"
    Locale["mn"]["translations-of"]    = "%s-н орчуулга"
    Locale["mn"]["definitions-of"]     = "%s үгийн тодорхойлолт"
    Locale["mn"]["synonyms"]           = "Ойролцоо утгатай"
    Locale["mn"]["examples"]           = "Жишээнүүд"
    Locale["mn"]["see-also"]           = "Мөн харах"
    Locale["mn"]["family"]             = "Mongolic"
    Locale["mn"]["iso"]                = "mon"
    Locale["mn"]["glotto"]             = "mong1331"
    Locale["mn"]["script"]             = "Cyrl"
    Locale["my"]["name"]               = "Myanmar"
    Locale["my"]["endonym"]            = "မြန်မာစာ"
    Locale["my"]["translations-of"]    = "%s၏ ဘာသာပြန်ဆိုချက်များ"
    Locale["my"]["definitions-of"]     = "%s၏ အနက်ဖွင့်ဆိုချက်များ"
    Locale["my"]["synonyms"]           = "ကြောင်းတူသံကွဲများ"
    Locale["my"]["examples"]           = "ဥပမာ"
    Locale["my"]["see-also"]           = "ဖော်ပြပါများကိုလဲ ကြည့်ပါ"
    Locale["my"]["family"]             = "Sino-Tibetan"
    Locale["my"]["iso"]                = "mya"
    Locale["my"]["glotto"]             = "nucl1310"
    Locale["my"]["script"]             = "Mymr"
    Locale["ne"]["name"]               = "Nepali"
    Locale["ne"]["endonym"]            = "नेपाली"
    Locale["ne"]["translations-of"]    = "%sका अनुवाद"
    Locale["ne"]["definitions-of"]     = "%sको परिभाषा"
    Locale["ne"]["synonyms"]           = "समानार्थीहरू"
    Locale["ne"]["examples"]           = "उदाहरणहरु"
    Locale["ne"]["see-also"]           = "यो पनि हेर्नुहोस्"
    Locale["ne"]["family"]             = "Indo-European"
    Locale["ne"]["iso"]                = "nep"
    Locale["ne"]["glotto"]             = "nepa1254"
    Locale["ne"]["script"]             = "Deva"
    Locale["no"]["name"]               = "Norwegian"
    Locale["no"]["endonym"]            = "Norsk"
    Locale["no"]["translations-of"]    = "Oversettelser av %s"
    Locale["no"]["definitions-of"]     = "Definisjoner av %s"
    Locale["no"]["synonyms"]           = "Synonymer"
    Locale["no"]["examples"]           = "Eksempler"
    Locale["no"]["see-also"]           = "Se også"
    Locale["no"]["family"]             = "Indo-European"
    Locale["no"]["iso"]                = "nor"
    Locale["no"]["glotto"]             = "norw1258"
    Locale["no"]["script"]             = "Latn"
    Locale["fa"]["name"]               = "Persian"
    Locale["fa"]["endonym"]            = "فارسی"
    Locale["fa"]["translations-of"]    = "ترجمه‌های %s"
    Locale["fa"]["definitions-of"]     = "تعریف‌های %s"
    Locale["fa"]["synonyms"]           = "مترادف‌ها"
    Locale["fa"]["examples"]           = "مثال‌ها"
    Locale["fa"]["see-also"]           = "همچنین مراجعه کنید به"
    Locale["fa"]["family"]             = "Indo-European"
    Locale["fa"]["iso"]                = "fas"
    Locale["fa"]["script"]             = "Arab"
    Locale["fa"]["rtl"]                = "true"
    Locale["pa"]["name"]               = "Punjabi"
    Locale["pa"]["endonym"]            = "ਪੰਜਾਬੀ"
    Locale["pa"]["translations-of"]    = "ਦੇ ਅਨੁਵਾਦ%s"
    Locale["pa"]["definitions-of"]     = "ਦੀਆਂ ਪਰਿਭਾਸ਼ਾ %s"
    Locale["pa"]["synonyms"]           = "ਸਮਾਨਾਰਥਕ ਸ਼ਬਦ"
    Locale["pa"]["examples"]           = "ਉਦਾਹਰਣਾਂ"
    Locale["pa"]["see-also"]           = "ਇਹ ਵੀ ਵੇਖੋ"
    Locale["pa"]["family"]             = "Indo-European"
    Locale["pa"]["iso"]                = "pan"
    Locale["pa"]["glotto"]             = "panj1256"
    Locale["pa"]["script"]             = "Guru"
    Locale["pl"]["name"]               = "Polish"
    Locale["pl"]["endonym"]            = "Polski"
    Locale["pl"]["translations-of"]    = "Tłumaczenia %s"
    Locale["pl"]["definitions-of"]     = "%s – definicje"
    Locale["pl"]["synonyms"]           = "Synonimy"
    Locale["pl"]["examples"]           = "Przykłady"
    Locale["pl"]["see-also"]           = "Zobacz też"
    Locale["pl"]["family"]             = "Indo-European"
    Locale["pl"]["iso"]                = "pol"
    Locale["pl"]["glotto"]             = "poli1260"
    Locale["pl"]["script"]             = "Latn"
    Locale["pt"]["name"]               = "Portuguese"
    Locale["pt"]["endonym"]            = "Português"
    Locale["pt"]["translations-of"]    = "Traduções de %s"
    Locale["pt"]["definitions-of"]     = "Definições de %s"
    Locale["pt"]["synonyms"]           = "Sinônimos"
    Locale["pt"]["examples"]           = "Exemplos"
    Locale["pt"]["see-also"]           = "Veja também"
    Locale["pt"]["family"]             = "Indo-European"
    Locale["pt"]["iso"]                = "por"
    Locale["pt"]["glotto"]             = "port1283"
    Locale["pt"]["script"]             = "Latn"
    Locale["ro"]["name"]               = "Romanian"
    Locale["ro"]["endonym"]            = "Română"
    Locale["ro"]["translations-of"]    = "Traduceri pentru %s"
    Locale["ro"]["definitions-of"]     = "Definiții pentru %s"
    Locale["ro"]["synonyms"]           = "Sinonime"
    Locale["ro"]["examples"]           = "Exemple"
    Locale["ro"]["see-also"]           = "Vedeți și"
    Locale["ro"]["family"]             = "Indo-European"
    Locale["ro"]["iso"]                = "ron"
    Locale["ro"]["glotto"]             = "roma1327"
    Locale["ro"]["script"]             = "Latn"
    Locale["ru"]["name"]               = "Russian"
    Locale["ru"]["endonym"]            = "Русский"
    Locale["ru"]["translations-of"]    = "%s: варианты перевода"
    Locale["ru"]["definitions-of"]     = "%s – определения"
    Locale["ru"]["synonyms"]           = "Синонимы"
    Locale["ru"]["examples"]           = "Примеры"
    Locale["ru"]["see-also"]           = "Похожие слова"
    Locale["ru"]["family"]             = "Indo-European"
    Locale["ru"]["iso"]                = "rus"
    Locale["ru"]["glotto"]             = "russ1263"
    Locale["ru"]["script"]             = "Cyrl"
    Locale["sr"]["name"]               = "Serbian"
    Locale["sr"]["endonym"]            = "српски"
    Locale["sr"]["translations-of"]    = "Преводи за „%s“"
    Locale["sr"]["definitions-of"]     = "Дефиниције за %s"
    Locale["sr"]["synonyms"]           = "Синоними"
    Locale["sr"]["examples"]           = "Примери"
    Locale["sr"]["see-also"]           = "Погледајте такође"
    Locale["sr"]["family"]             = "Indo-European"
    Locale["sr"]["iso"]                = "srp"
    Locale["sr"]["glotto"]             = "serb1264"
    Locale["sr"]["script"]             = "Cyrl"
    Locale["st"]["name"]               = "Sesotho"
    Locale["st"]["endonym"]            = "Sesotho"
    Locale["st"]["translations-of"]    = "Liphetolelo tsa %s"
    Locale["st"]["definitions-of"]     = "Meelelo ea %s"
    Locale["st"]["synonyms"]           = "Mantsoe a tšoanang ka moelelo"
    Locale["st"]["examples"]           = "Mehlala"
    Locale["st"]["see-also"]           = "Bona hape"
    Locale["st"]["family"]             = "Atlantic-Congo"
    Locale["st"]["iso"]                = "sot"
    Locale["st"]["glotto"]             = "sout2807"
    Locale["st"]["script"]             = "Latn"
    Locale["si"]["name"]               = "Sinhala"
    Locale["si"]["endonym"]            = "සිංහල"
    Locale["si"]["translations-of"]    = "%s හි පරිවර්තන"
    Locale["si"]["definitions-of"]     = "%s හි නිර්වචන"
    Locale["si"]["synonyms"]           = "සමානාර්ථ පද"
    Locale["si"]["examples"]           = "උදාහරණ"
    Locale["si"]["see-also"]           = "මෙයත් බලන්න"
    Locale["si"]["family"]             = "Indo-European"
    Locale["si"]["iso"]                = "sin"
    Locale["si"]["glotto"]             = "sinh1246"
    Locale["si"]["script"]             = "Sinh"
    Locale["sk"]["name"]               = "Slovak"
    Locale["sk"]["endonym"]            = "Slovenčina"
    Locale["sk"]["translations-of"]    = "Preklady výrazu: %s"
    Locale["sk"]["definitions-of"]     = "Definície výrazu %s"
    Locale["sk"]["synonyms"]           = "Synonymá"
    Locale["sk"]["examples"]           = "Príklady"
    Locale["sk"]["see-also"]           = "Pozrite tiež"
    Locale["sk"]["family"]             = "Indo-European"
    Locale["sk"]["iso"]                = "slk"
    Locale["sk"]["glotto"]             = "slov1269"
    Locale["sk"]["script"]             = "Latn"
    Locale["sl"]["name"]               = "Slovenian"
    Locale["sl"]["endonym"]            = "Slovenščina"
    Locale["sl"]["translations-of"]    = "Prevodi za %s"
    Locale["sl"]["definitions-of"]     = "Razlage za %s"
    Locale["sl"]["synonyms"]           = "Sopomenke"
    Locale["sl"]["examples"]           = "Primeri"
    Locale["sl"]["see-also"]           = "Glejte tudi"
    Locale["sl"]["family"]             = "Indo-European"
    Locale["sl"]["iso"]                = "slv"
    Locale["sl"]["glotto"]             = "slov1268"
    Locale["sl"]["script"]             = "Latn"
    Locale["so"]["name"]               = "Somali"
    Locale["so"]["endonym"]            = "Soomaali"
    Locale["so"]["translations-of"]    = "Turjumaada %s"
    Locale["so"]["definitions-of"]     = "Qeexitaannada %s"
    Locale["so"]["synonyms"]           = "La micne ah"
    Locale["so"]["examples"]           = "Tusaalooyin"
    Locale["so"]["see-also"]           = "Sidoo kale eeg"
    Locale["so"]["family"]             = "Afro-Asiatic"
    Locale["so"]["iso"]                = "som"
    Locale["so"]["glotto"]             = "soma1255"
    Locale["so"]["script"]             = "Latn"
    Locale["es"]["name"]               = "Spanish"
    Locale["es"]["endonym"]            = "Español"
    Locale["es"]["translations-of"]    = "Traducciones de %s"
    Locale["es"]["definitions-of"]     = "Definiciones de %s"
    Locale["es"]["synonyms"]           = "Sinónimos"
    Locale["es"]["examples"]           = "Ejemplos"
    Locale["es"]["see-also"]           = "Ver también"
    Locale["es"]["family"]             = "Indo-European"
    Locale["es"]["iso"]                = "spa"
    Locale["es"]["glotto"]             = "stan1288"
    Locale["es"]["script"]             = "Latn"
    Locale["su"]["name"]               = "Sundanese"
    Locale["su"]["endonym"]            = "Basa Sunda"
    Locale["su"]["translations-of"]    = "Tarjamahan tina %s"
    Locale["su"]["definitions-of"]     = "Panjelasan tina %s"
    Locale["su"]["synonyms"]           = "Sinonim"
    Locale["su"]["examples"]           = "Conto"
    Locale["su"]["see-also"]           = "Tingali ogé"
    Locale["su"]["family"]             = "Austronesian"
    Locale["su"]["iso"]                = "sun"
    Locale["su"]["glotto"]             = "sund1252"
    Locale["su"]["script"]             = "Latn"
    Locale["sw"]["name"]               = "Swahili"
    Locale["sw"]["endonym"]            = "Kiswahili"
    Locale["sw"]["translations-of"]    = "Tafsiri ya %s"
    Locale["sw"]["definitions-of"]     = "Ufafanuzi wa %s"
    Locale["sw"]["synonyms"]           = "Visawe"
    Locale["sw"]["examples"]           = "Mifano"
    Locale["sw"]["see-also"]           = "Angalia pia"
    Locale["sw"]["family"]             = "Atlantic-Congo"
    Locale["sw"]["iso"]                = "swa"
    Locale["sw"]["glotto"]             = "swah1253"
    Locale["sw"]["script"]             = "Latn"
    Locale["sv"]["name"]               = "Swedish"
    Locale["sv"]["endonym"]            = "Svenska"
    Locale["sv"]["translations-of"]    = "Översättningar av %s"
    Locale["sv"]["definitions-of"]     = "Definitioner av %s"
    Locale["sv"]["synonyms"]           = "Synonymer"
    Locale["sv"]["examples"]           = "Exempel"
    Locale["sv"]["see-also"]           = "Se även"
    Locale["sv"]["family"]             = "Indo-European"
    Locale["sv"]["iso"]                = "swe"
    Locale["sv"]["glotto"]             = "swed1254"
    Locale["sv"]["script"]             = "Latn"
    Locale["tg"]["name"]               = "Tajik"
    Locale["tg"]["endonym"]            = "Тоҷикӣ"
    Locale["tg"]["translations-of"]    = "Тарҷумаҳои %s"
    Locale["tg"]["definitions-of"]     = "Таърифҳои %s"
    Locale["tg"]["synonyms"]           = "Муродифҳо"
    Locale["tg"]["examples"]           = "Намунаҳо:"
    Locale["tg"]["see-also"]           = "Ҳамчунин Бинед"
    Locale["tg"]["family"]             = "Indo-European"
    Locale["tg"]["iso"]                = "tgk"
    Locale["tg"]["glotto"]             = "taji1245"
    Locale["tg"]["script"]             = "Cyrl"
    Locale["ta"]["name"]               = "Tamil"
    Locale["ta"]["endonym"]            = "தமிழ்"
    Locale["ta"]["translations-of"]    = "%s இன் மொழிபெயர்ப்புகள்"
    Locale["ta"]["definitions-of"]     = "%s இன் வரையறைகள்"
    Locale["ta"]["synonyms"]           = "இணைச்சொற்கள்"
    Locale["ta"]["examples"]           = "எடுத்துக்காட்டுகள்"
    Locale["ta"]["see-also"]           = "இதையும் காண்க"
    Locale["ta"]["family"]             = "Dravidian"
    Locale["ta"]["iso"]                = "tam"
    Locale["ta"]["glotto"]             = "tami1289"
    Locale["ta"]["script"]             = "Taml"
    Locale["te"]["name"]               = "Telugu"
    Locale["te"]["endonym"]            = "తెలుగు"
    Locale["te"]["translations-of"]    = "%s యొక్క అనువాదాలు"
    Locale["te"]["definitions-of"]     = "%s యొక్క నిర్వచనాలు"
    Locale["te"]["synonyms"]           = "పర్యాయపదాలు"
    Locale["te"]["examples"]           = "ఉదాహరణలు"
    Locale["te"]["see-also"]           = "వీటిని కూడా చూడండి"
    Locale["te"]["family"]             = "Dravidian"
    Locale["te"]["iso"]                = "tel"
    Locale["te"]["glotto"]             = "telu1262"
    Locale["te"]["script"]             = "Telu"
    Locale["th"]["name"]               = "Thai"
    Locale["th"]["endonym"]            = "ไทย"
    Locale["th"]["translations-of"]    = "คำแปลของ %s"
    Locale["th"]["definitions-of"]     = "คำจำกัดความของ %s"
    Locale["th"]["synonyms"]           = "คำพ้องความหมาย"
    Locale["th"]["examples"]           = "ตัวอย่าง"
    Locale["th"]["see-also"]           = "ดูเพิ่มเติม"
    Locale["th"]["family"]             = "Tai–Kadai"
    Locale["th"]["iso"]                = "tha"
    Locale["th"]["glotto"]             = "thai1261"
    Locale["th"]["script"]             = "Thai"
    Locale["tr"]["name"]               = "Turkish"
    Locale["tr"]["endonym"]            = "Türkçe"
    Locale["tr"]["translations-of"]    = "%s çevirileri"
    Locale["tr"]["definitions-of"]     = "%s için tanımlar"
    Locale["tr"]["synonyms"]           = "Eş anlamlılar"
    Locale["tr"]["examples"]           = "Örnekler"
    Locale["tr"]["see-also"]           = "Ayrıca bkz."
    Locale["tr"]["family"]             = "Turkic"
    Locale["tr"]["iso"]                = "tur"
    Locale["tr"]["glotto"]             = "nucl1301"
    Locale["tr"]["script"]             = "Latn"
    Locale["uk"]["name"]               = "Ukrainian"
    Locale["uk"]["endonym"]            = "Українська"
    Locale["uk"]["translations-of"]    = "Переклади слова або виразу \"%s\""
    Locale["uk"]["definitions-of"]     = "\"%s\" – визначення"
    Locale["uk"]["synonyms"]           = "Синоніми"
    Locale["uk"]["examples"]           = "Приклади"
    Locale["uk"]["see-also"]           = "Дивіться також"
    Locale["uk"]["family"]             = "Indo-European"
    Locale["uk"]["iso"]                = "ukr"
    Locale["uk"]["glotto"]             = "ukra1253"
    Locale["uk"]["script"]             = "Cyrl"
    Locale["ur"]["name"]               = "Urdu"
    Locale["ur"]["endonym"]            = "اُردُو"
    Locale["ur"]["translations-of"]    = "کے ترجمے %s"
    Locale["ur"]["definitions-of"]     = "کی تعریفات %s"
    Locale["ur"]["synonyms"]           = "مترادفات"
    Locale["ur"]["examples"]           = "مثالیں"
    Locale["ur"]["see-also"]           = "نیز دیکھیں"
    Locale["ur"]["family"]             = "Indo-European"
    Locale["ur"]["iso"]                = "urd"
    Locale["ur"]["glotto"]             = "urdu1245"
    Locale["ur"]["script"]             = "Arab"
    Locale["ur"]["rtl"]                = "true"
    Locale["uz"]["name"]               = "Uzbek"
    Locale["uz"]["endonym"]            = "Oʻzbek tili"
    Locale["uz"]["translations-of"]    = "%s: tarjima variantlari"
    Locale["uz"]["definitions-of"]     = "%s – ta’riflar"
    Locale["uz"]["synonyms"]           = "Sinonimlar"
    Locale["uz"]["examples"]           = "Namunalar"
    Locale["uz"]["see-also"]           = "O‘xshash so‘zlar"
    Locale["uz"]["family"]             = "Turkic"
    Locale["uz"]["iso"]                = "uzb"
    Locale["uz"]["glotto"]             = "uzbe1247"
    Locale["uz"]["script"]             = "Latn"
    Locale["vi"]["name"]               = "Vietnamese"
    Locale["vi"]["endonym"]            = "Tiếng Việt"
    Locale["vi"]["translations-of"]    = "Bản dịch của %s"
    Locale["vi"]["definitions-of"]     = "Nghĩa của %s"
    Locale["vi"]["synonyms"]           = "Từ đồng nghĩa"
    Locale["vi"]["examples"]           = "Ví dụ"
    Locale["vi"]["see-also"]           = "Xem thêm"
    Locale["vi"]["family"]             = "Austroasiatic"
    Locale["vi"]["iso"]                = "vie"
    Locale["vi"]["glotto"]             = "viet1252"
    Locale["vi"]["script"]             = "Latn"
    Locale["cy"]["name"]               = "Welsh"
    Locale["cy"]["endonym"]            = "Cymraeg"
    Locale["cy"]["translations-of"]    = "Cyfieithiadau %s"
    Locale["cy"]["definitions-of"]     = "Diffiniadau %s"
    Locale["cy"]["synonyms"]           = "Cyfystyron"
    Locale["cy"]["examples"]           = "Enghreifftiau"
    Locale["cy"]["see-also"]           = "Gweler hefyd"
    Locale["cy"]["family"]             = "Indo-European"
    Locale["cy"]["iso"]                = "cym"
    Locale["cy"]["glotto"]             = "wels1247"
    Locale["cy"]["script"]             = "Latn"
    Locale["yi"]["name"]               = "Yiddish"
    Locale["yi"]["endonym"]            = "ייִדיש"
    Locale["yi"]["translations-of"]    = "איבערזעצונגען פון %s"
    Locale["yi"]["definitions-of"]     = "דפיניציונען %s"
    Locale["yi"]["synonyms"]           = "סינאָנימען"
    Locale["yi"]["examples"]           = "ביישפילע"
    Locale["yi"]["see-also"]           = "זייען אויך"
    Locale["yi"]["family"]             = "Indo-European"
    Locale["yi"]["iso"]                = "yid"
    Locale["yi"]["glotto"]             = "yidd1255"
    Locale["yi"]["script"]             = "Hebr"
    Locale["yi"]["rtl"]                = "true"
    Locale["yo"]["name"]               = "Yoruba"
    Locale["yo"]["endonym"]            = "Yorùbá"
    Locale["yo"]["translations-of"]    = "Awọn itumọ ti %s"
    Locale["yo"]["definitions-of"]     = "Awọn itumọ ti %s"
    Locale["yo"]["synonyms"]           = "Awọn ọrọ onitumọ"
    Locale["yo"]["examples"]           = "Awọn apẹrẹ"
    Locale["yo"]["see-also"]           = "Tun wo"
    Locale["yo"]["family"]             = "Atlantic-Congo"
    Locale["yo"]["iso"]                = "yor"
    Locale["yo"]["glotto"]             = "yoru1245"
    Locale["yo"]["script"]             = "Latn"
    Locale["zu"]["name"]               = "Zulu"
    Locale["zu"]["endonym"]            = "isiZulu"
    Locale["zu"]["translations-of"]    = "Ukuhumusha i-%s"
    Locale["zu"]["definitions-of"]     = "Izincazelo ze-%s"
    Locale["zu"]["synonyms"]           = "Amagama afanayo"
    Locale["zu"]["examples"]           = "Izibonelo"
    Locale["zu"]["see-also"]           = "Bheka futhi"
    Locale["zu"]["family"]             = "Atlantic-Congo"
    Locale["zu"]["iso"]                = "zul"
    Locale["zu"]["glotto"]             = "zulu1248"
    Locale["zu"]["script"]             = "Latn"
    LocaleAlias["in"] = "id"
    LocaleAlias["iw"] = "he"
    LocaleAlias["ji"] = "yi"
    LocaleAlias["jw"] = "jv"
    LocaleAlias["mo"] = "ro"
    LocaleAlias["sh"] = "sr"
    LocaleAlias["zh"] = "zh-CN"
}
function getCode(code) {
    if (code == "auto" || code in Locale)
        return code
    else if (code in LocaleAlias)
        return LocaleAlias[code]
    else
        return
}
function getName(code) {
    return Locale[getCode(code)]["name"]
}
function getEndonym(code) {
    return Locale[getCode(code)]["endonym"]
}
function getDisplay(code) {
    return Locale[getCode(code)]["display"]
}
function showTranslationsOf(code, text,    fmt) {
    fmt = Locale[getCode(code)]["translations-of"]
    if (!fmt) fmt = Locale["en"]["translations-of"]
    return sprintf(fmt, text)
}
function showDefinitionsOf(code, text,    fmt) {
    fmt = Locale[getCode(code)]["definitions-of"]
    if (!fmt) fmt = Locale["en"]["definitions-of"]
    return sprintf(fmt, text)
}
function showSynonyms(code,    tmp) {
    tmp = Locale[getCode(code)]["synonyms"]
    if (!tmp) tmp = Locale["en"]["synonyms"]
    return tmp
}
function showExamples(code,    tmp) {
    tmp = Locale[getCode(code)]["examples"]
    if (!tmp) tmp = Locale["en"]["examples"]
    return tmp
}
function showSeeAlso(code,    tmp) {
    tmp = Locale[getCode(code)]["see-also"]
    if (!tmp) tmp = Locale["en"]["see-also"]
    return tmp
}
function getFamily(code) {
    return Locale[getCode(code)]["family"]
}
function getISO(code) {
    return Locale[getCode(code)]["iso"]
}
function getGlotto(code) {
    return Locale[getCode(code)]["glotto"]
}
function getScript(code) {
    return Locale[getCode(code)]["script"]
}
function isRTL(code) {
    return Locale[getCode(code)]["rtl"] ? 1 : 0
}
function initBiDi() {
    "fribidi --version" SUPERR |& getline FriBidi
    BiDiNoPad = FriBidi ? "fribidi --nopad" : "rev"
    BiDi = FriBidi ? "fribidi --width %s" : "rev | sed \"s/'/\\\\\\'/\" | xargs printf '%%s '"
}
function showPhonetics(phonetics, code) {
    if (code && getCode(code) == "en")
        return "/" phonetics "/"
    else
        return "(" phonetics ")"
}
function show(text, code,    temp) {
    if (!code || Locale[getCode(code)]["rtl"]) {
        if (Cache[text][0])
            return Cache[text][0]
        else {
            if (FriBidi || (code && Locale[getCode(code)]["rtl"]))
                ("echo " parameterize(text) " | " BiDiNoPad) | getline temp
            else
                temp = text
            return Cache[text][0] = temp
        }
    } else
        return text
}
function s(text, code, width,    temp) {
    if (!code || Locale[getCode(code)]["rtl"]) {
        if (!width) width = Option["width"]
        if (Cache[text][width])
            return Cache[text][width]
        else {
            if (FriBidi || (code && Locale[getCode(code)]["rtl"]))
                ("echo " parameterize(text) " | " sprintf(BiDi, width)) | getline temp
            else
                temp = text
            return Cache[text][width] = temp
        }
    } else
        return text
}
function ins(level, text, code, width,    i, temp) {
    if (code && Locale[getCode(code)]["rtl"]) {
        if (!width) width = Option["width"]
        return s(text, code, width - level * length(I))
    } else
        return replicate(" ", Option["indent"] * level) text
}
function initLocaleDisplay(    i) {
    for (i in Locale)
        Locale[i]["display"] = show(Locale[i]["endonym"], i)
}
function parseLang(lang,    code, group) {
    match(lang, /^([a-z][a-z][a-z]?)(_|$)/, group)
    code = getCode(group[1])
    if (lang ~ /^zh_(CN|SG)/) code = "zh-CN"
    else if (lang ~ /^zh_(TW|HK)/) code = "zh-TW"
    if (!code) code = "en"
    return code
}
function initUserLang(    locale) {
    locale = ENVIRON["LANGUAGE"] ? ENVIRON["LANGUAGE"] :
        (ENVIRON["LC_ALL"] ? ENVIRON["LC_ALL"] :
         (ENVIRON["LC_CTYPE"] ? ENVIRON["LC_CTYPE"] :
          (ENVIRON["LC_MESSAGES"] ? ENVIRON["LC_MESSAGES"] :
           (ENVIRON["LANG"] ? ENVIRON["LANG"] : "en_US.UTF-8"))))
    if (tolower(locale) !~ /utf-?8$/)
        w("[WARNING] Your locale codeset (" locale ") is not UTF-8.")
    UserLang = parseLang(locale)
}
function getVersion() {
    return Name " " Version
}
function getReference(displayName) {
    if (displayName == "name")
        return "┌─────────────────────────────┬──────────────────────┬─────────────────┐" RS\
            "│ " getName("af") "           - " ansi("bold", "af") "    │ "\
            getName("ha") "          - " ansi("bold", "ha") "  │ "\
            getName("fa") "    - " ansi("bold", "fa") " │" RS\
            "│ " getName("sq") "            - " ansi("bold", "sq") "    │ "\
            getName("he") "         - " ansi("bold", "he") "  │ "\
            getName("pl") "     - " ansi("bold", "pl") " │" RS\
            "│ " getName("ar") "              - " ansi("bold", "ar") "    │ "\
            getName("hi") "          - " ansi("bold", "hi") "  │ "\
            getName("pt") " - " ansi("bold", "pt") " │" RS\
            "│ " getName("hy") "            - " ansi("bold", "hy") "    │ "\
            getName("hmn") "          - " ansi("bold", "hmn") " │ "\
            getName("pa") "    - " ansi("bold", "pa") " │" RS\
            "│ " getName("az") "         - " ansi("bold", "az") "    │ "\
            getName("hu") "      - " ansi("bold", "hu") "  │ "\
            getName("ro") "   - " ansi("bold", "ro") " │" RS\
            "│ " getName("eu") "              - " ansi("bold", "eu") "    │ "\
            getName("is") "      - " ansi("bold", "is") "  │ "\
            getName("ru") "    - " ansi("bold", "ru") " │" RS\
            "│ " getName("be") "          - " ansi("bold", "be") "    │ "\
            getName("ig") "           - " ansi("bold", "ig") "  │ "\
            getName("sr") "    - " ansi("bold", "sr") " │" RS\
            "│ " getName("bn") "             - " ansi("bold", "bn") "    │ "\
            getName("id") "     - " ansi("bold", "id") "  │ "\
            getName("st") "    - " ansi("bold", "st") " │" RS\
            "│ " getName("bs") "             - " ansi("bold", "bs") "    │ "\
            getName("ga") "          - " ansi("bold", "ga") "  │ "\
            getName("si") "    - " ansi("bold", "si") " │" RS\
            "│ " getName("bg") "           - " ansi("bold", "bg") "    │ "\
            getName("it") "        - " ansi("bold", "it") "  │ "\
            getName("sk") "     - " ansi("bold", "sk") " │" RS\
            "│ " getName("ca") "             - " ansi("bold", "ca") "    │ "\
            getName("ja") "       - " ansi("bold", "ja") "  │ "\
            getName("sl") "  - " ansi("bold", "sl") " │" RS\
            "│ " getName("ceb") "             - " ansi("bold", "ceb") "   │ "\
            getName("jv") "       - " ansi("bold", "jv") "  │ "\
            getName("so") "     - " ansi("bold", "so") " │" RS\
            "│ " getName("ny") "            - " ansi("bold", "ny") "    │ "\
            getName("kn") "        - " ansi("bold", "kn") "  │ "\
            getName("es") "    - " ansi("bold", "es") " │" RS\
            "│ " getName("zh-CN") "  - " ansi("bold", "zh-CN") " │ "\
            getName("kk") "         - " ansi("bold", "kk") "  │ "\
            getName("su") "  - " ansi("bold", "su") " │" RS\
            "│ " getName("zh-TW") " - " ansi("bold", "zh-TW") " │ "\
            getName("km") "          - " ansi("bold", "km") "  │ "\
            getName("sw") "    - " ansi("bold", "sw") " │" RS\
            "│ " getName("hr") "            - " ansi("bold", "hr") "    │ "\
            getName("ko") "         - " ansi("bold", "ko") "  │ "\
            getName("sv") "    - " ansi("bold", "sv") " │" RS\
            "│ " getName("cs") "               - " ansi("bold", "cs") "    │ "\
            getName("lo") "            - " ansi("bold", "lo") "  │ "\
            getName("tg") "      - " ansi("bold", "tg") " │" RS\
            "│ " getName("da") "              - " ansi("bold", "da") "    │ "\
            getName("la") "          - " ansi("bold", "la") "  │ "\
            getName("ta") "      - " ansi("bold", "ta") " │" RS\
            "│ " getName("nl") "               - " ansi("bold", "nl") "    │ "\
            getName("lv") "        - " ansi("bold", "lv") "  │ "\
            getName("te") "     - " ansi("bold", "te") " │" RS\
            "│ " getName("en") "             - " ansi("bold", "en") "    │ "\
            getName("lt") "     - " ansi("bold", "lt") "  │ "\
            getName("th") "       - " ansi("bold", "th") " │" RS\
            "│ " getName("eo") "           - " ansi("bold", "eo") "    │ "\
            getName("mk") "     - " ansi("bold", "mk") "  │ "\
            getName("tr") "    - " ansi("bold", "tr") " │" RS\
            "│ " getName("et") "            - " ansi("bold", "et") "    │ "\
            getName("mg") "       - " ansi("bold", "mg") "  │ "\
            getName("uk") "  - " ansi("bold", "uk") " │" RS\
            "│ " getName("tl") "            - " ansi("bold", "tl") "    │ "\
            getName("ms") "          - " ansi("bold", "ms") "  │ "\
            getName("ur") "       - " ansi("bold", "ur") " │" RS\
            "│ " getName("fi") "             - " ansi("bold", "fi") "    │ "\
            getName("ml") "      - " ansi("bold", "ml") "  │ "\
            getName("uz") "      - " ansi("bold", "uz") " │" RS\
            "│ " getName("fr") "              - " ansi("bold", "fr") "    │ "\
            getName("mt") "        - " ansi("bold", "mt") "  │ "\
            getName("vi") " - " ansi("bold", "vi") " │" RS\
            "│ " getName("gl") "            - " ansi("bold", "gl") "    │ "\
            getName("mi") "          - " ansi("bold", "mi") "  │ "\
            getName("cy") "      - " ansi("bold", "cy") " │" RS\
            "│ " getName("ka") "            - " ansi("bold", "ka") "    │ "\
            getName("mr") "        - " ansi("bold", "mr") "  │ "\
            getName("yi") "    - " ansi("bold", "yi") " │" RS\
            "│ " getName("de") "              - " ansi("bold", "de") "    │ "\
            getName("mn") "      - " ansi("bold", "mn") "  │ "\
            getName("yo") "     - " ansi("bold", "yo") " │" RS\
            "│ " getName("el") "               - " ansi("bold", "el") "    │ "\
            getName("my") "        - " ansi("bold", "my") "  │ "\
            getName("zu") "       - " ansi("bold", "zu") " │" RS\
            "│ " getName("gu") "            - " ansi("bold", "gu") "    │ "\
            getName("ne") "         - " ansi("bold", "ne") "  │ "\
            "                │" RS\
            "│ " getName("ht") "      - " ansi("bold", "ht") "    │ "\
            getName("no") "      - " ansi("bold", "no") "  │ "\
            "                │" RS\
            "└─────────────────────────────┴──────────────────────┴─────────────────┘"
    else
        return "┌──────────────────────┬───────────────────────┬─────────────────────┐" RS\
            "│ " getDisplay("af") "      - " ansi("bold", "af") "  │ "\
            getDisplay("hu") "           - " ansi("bold", "hu") " │ "\
            getDisplay("pl") "      - " ansi("bold", "pl") "    │" RS\
            "│ " getDisplay("ar") "        - " ansi("bold", "ar") "  │ "\
            getDisplay("hy") "          - " ansi("bold", "hy") " │ "\
            getDisplay("pt") "   - " ansi("bold", "pt") "    │" RS\
            "│ " getDisplay("az") "   - " ansi("bold", "az") "  │ "\
            getDisplay("id") " - " ansi("bold", "id") " │ "\
            getDisplay("ro") "      - " ansi("bold", "ro") "    │" RS\
            "│ " getDisplay("be") "     - " ansi("bold", "be") "  │ "\
            getDisplay("ig") "             - " ansi("bold", "ig") " │ "\
            getDisplay("ru") "     - " ansi("bold", "ru") "    │" RS\
            "│ " getDisplay("bg") "      - " ansi("bold", "bg") "  │ "\
            getDisplay("is") "         - " ansi("bold", "is") " │ "\
            getDisplay("si") "        - " ansi("bold", "si") "    │" RS\
            "│ " getDisplay("bn") "          - " ansi("bold", "bn") "  │ "\
            getDisplay("it") "         - " ansi("bold", "it") " │ "\
            getDisplay("sk") "  - " ansi("bold", "sk") "    │" RS\
            "│ " getDisplay("bs") "       - " ansi("bold", "bs") "  │ "\
            getDisplay("ja") "           - " ansi("bold", "ja") " │ "\
            getDisplay("sl") " - " ansi("bold", "sl") "    │" RS\
            "│ " getDisplay("ca") "         - " ansi("bold", "ca") "  │ "\
            getDisplay("jv") "        - " ansi("bold", "jv") " │ "\
            getDisplay("so") "    - " ansi("bold", "so") "    │" RS\
            "│ " getDisplay("ceb") "        - " ansi("bold", "ceb") " │ "\
            getDisplay("ka") "          - " ansi("bold", "ka") " │ "\
            getDisplay("sq") "       - " ansi("bold", "sq") "    │" RS\
            "│ " getDisplay("cs") "        - " ansi("bold", "cs") "  │ "\
            getDisplay("kk") "       - " ansi("bold", "kk") " │ "\
            getDisplay("sr") "      - " ansi("bold", "sr") "    │" RS\
            "│ " getDisplay("cy") "        - " ansi("bold", "cy") "  │ "\
            getDisplay("km") "         - " ansi("bold", "km") " │ "\
            getDisplay("st") "     - " ansi("bold", "st") "    │" RS\
            "│ " getDisplay("da") "          - " ansi("bold", "da") "  │ "\
            getDisplay("kn") "             - " ansi("bold", "kn") " │ "\
            getDisplay("su") "  - " ansi("bold", "su") "    │" RS\
            "│ " getDisplay("de") "        - " ansi("bold", "de") "  │ "\
            getDisplay("ko") "           - " ansi("bold", "ko") " │ "\
            getDisplay("sv") "     - " ansi("bold", "sv") "    │" RS\
            "│ " getDisplay("el") "       - " ansi("bold", "el") "  │ "\
            getDisplay("la") "           - " ansi("bold", "la") " │ "\
            getDisplay("sw") "   - " ansi("bold", "sw") "    │" RS\
            "│ " getDisplay("en") "        - " ansi("bold", "en") "  │ "\
            getDisplay("lo") "              - " ansi("bold", "lo") " │ "\
            getDisplay("ta") "        - " ansi("bold", "ta") "    │" RS\
            "│ " getDisplay("eo") "      - " ansi("bold", "eo") "  │ "\
            getDisplay("lt") "         - " ansi("bold", "lt") " │ "\
            getDisplay("te") "       - " ansi("bold", "te") "    │" RS\
            "│ " getDisplay("es") "        - " ansi("bold", "es") "  │ "\
            getDisplay("lv") "         - " ansi("bold", "lv") " │ "\
            getDisplay("tg") "      - " ansi("bold", "tg") "    │" RS\
            "│ " getDisplay("et") "          - " ansi("bold", "et") "  │ "\
            getDisplay("mg") "         - " ansi("bold", "mg") " │ "\
            getDisplay("th") "         - " ansi("bold", "th") "    │" RS\
            "│ " getDisplay("eu") "        - " ansi("bold", "eu") "  │ "\
            getDisplay("mi") "            - " ansi("bold", "mi") " │ "\
            getDisplay("tl") "     - " ansi("bold", "tl") "    │" RS\
            "│ " getDisplay("fa") "          - " ansi("bold", "fa") "  │ "\
            getDisplay("mk") "       - " ansi("bold", "mk") " │ "\
            getDisplay("tr") "      - " ansi("bold", "tr") "    │" RS\
            "│ " getDisplay("fi") "          - " ansi("bold", "fi") "  │ "\
            getDisplay("ml") "           - " ansi("bold", "ml") " │ "\
            getDisplay("uk") "  - " ansi("bold", "uk") "    │" RS\
            "│ " getDisplay("fr") "       - " ansi("bold", "fr") "  │ "\
            getDisplay("mn") "           - " ansi("bold", "mn") " │ "\
            getDisplay("ur") "        - " ansi("bold", "ur") "    │" RS\
            "│ " getDisplay("ga") "        - " ansi("bold", "ga") "  │ "\
            getDisplay("mr") "            - " ansi("bold", "mr") " │ "\
            getDisplay("uz") " - " ansi("bold", "uz") "    │" RS\
            "│ " getDisplay("gl") "         - " ansi("bold", "gl") "  │ "\
            getDisplay("ms") "    - " ansi("bold", "ms") " │ "\
            getDisplay("vi") "  - " ansi("bold", "vi") "    │" RS\
            "│ " getDisplay("gu") "         - " ansi("bold", "gu") "  │ "\
            getDisplay("mt") "            - " ansi("bold", "mt") " │ "\
            getDisplay("yi") "       - " ansi("bold", "yi") "    │" RS\
            "│ " getDisplay("ha") "          - " ansi("bold", "ha") "  │ "\
            getDisplay("my") "          - " ansi("bold", "my") " │ "\
            getDisplay("yo") "      - " ansi("bold", "yo") "    │" RS\
            "│ " getDisplay("he") "          - " ansi("bold", "he") "  │ "\
            getDisplay("ne") "            - " ansi("bold", "ne") " │ "\
            getDisplay("zh-CN") "    - " ansi("bold", "zh-CN") " │" RS\
            "│ " getDisplay("hi") "          - " ansi("bold", "hi") "  │ "\
            getDisplay("nl") "       - " ansi("bold", "nl") " │ "\
            getDisplay("zh-TW") "    - " ansi("bold", "zh-TW") " │" RS\
            "│ " getDisplay("hmn") "          - " ansi("bold", "hmn") " │ "\
            getDisplay("no") "            - " ansi("bold", "no") " │ "\
            getDisplay("zu") "     - " ansi("bold", "zu") "    │" RS\
            "│ " getDisplay("hr") "       - " ansi("bold", "hr") "  │ "\
            getDisplay("ny") "           - " ansi("bold", "ny") " │ "\
            "                    │" RS\
            "│ " getDisplay("ht") " - " ansi("bold", "ht") "  │ "\
            getDisplay("pa") "            - " ansi("bold", "pa") " │ "\
            "                    │" RS\
            "└──────────────────────┴───────────────────────┴─────────────────────┘"
}
function getHelp() {
    return "Usage:\t" Command " [options] [source]:[target] [" ansi("underline", "text") "] ..." RS\
        "\t" Command " [options] [source]:[target1]+[target2]+... [" ansi("underline", "text") "] ..." RS RS\
        "Options:" RS\
        ansi("bold", "-V, -version") RS\
        ins(1, "Print version and exit.") RS\
        ansi("bold", "-H, -h, -help") RS\
        ins(1, "Print this help message and exit.") RS\
        ansi("bold", "-M, -m, -manual") RS\
        ins(1, "Show the manual.") RS\
        ansi("bold", "-r, -reference") RS\
        ins(1, "Print a list of languages (displayed in endonyms) and their ISO 639 codes for reference, and exit.") RS\
        ansi("bold", "-R, -reference-english") RS\
        ins(1, "Print a list of languages (displayed in English names) and their ISO 639 codes for reference, and exit.") RS\
        ansi("bold", "-v, -verbose") RS\
        ins(1, "Verbose mode. (default)") RS\
        ansi("bold", "-b, -brief") RS\
        ins(1, "Brief mode.") RS\
        ansi("bold", "-show-original [yes|no]") RS\
        ins(1, "Show original text or not. (default: yes)") RS\
        ansi("bold", "-show-original-phonetics [yes|no]") RS\
        ins(1, "Show phonetic notation of original text or not. (default: yes)") RS\
        ansi("bold", "-show-translation [yes|no]") RS\
        ins(1, "Show translation or not. (default: yes)") RS\
        ansi("bold", "-show-translation-phonetics [yes|no]") RS\
        ins(1, "Show phonetic notation of translation or not. (default: yes)") RS\
        ansi("bold", "-show-prompt-message [yes|no]") RS\
        ins(1, "Show prompt message or not. (default: yes)") RS\
        ansi("bold", "-show-languages [yes|no]") RS\
        ins(1, "Show source and target languages or not. (default: yes)") RS\
        ansi("bold", "-show-original-dictionary [yes|no]") RS\
        ins(1, "Show dictionary entry of original text or not. (default: no)") RS\
        ansi("bold", "-show-dictionary [yes|no]") RS\
        ins(1, "Show dictionary entry of translation or not. (default: yes)") RS\
        ansi("bold", "-show-alternatives [yes|no]") RS\
        ins(1, "Show alternative translations or not. (default: yes)") RS\
        ansi("bold", "-no-ansi") RS\
        ins(1, "Don't use ANSI escape codes in the translation.") RS\
        ansi("bold", "-w [num], -width [num]") RS\
        ins(1, "Specify the screen width for padding when displaying right-to-left languages.") RS\
        ansi("bold", "-indent [num]") RS\
        ins(1, "Specify the size of indent (in terms of spaces). (default: 4)") RS\
        ansi("bold", "-browser [program]") RS\
        ins(1, "Specify the web browser to use.") RS\
        ansi("bold", "-p, -play") RS\
        ins(1, "Listen to the translation.") RS\
        ansi("bold", "-player [program]") RS\
        ins(1, "Specify the command-line audio player to use, and listen to the translation.") RS\
        ansi("bold", "-x [proxy], -proxy [proxy]") RS\
        ins(1, "Use proxy on given port.") RS\
        ansi("bold", "-I, -interactive") RS\
        ins(1, "Start an interactive shell, invoking `rlwrap` whenever possible (unless `-no-rlwrap` is specified).") RS\
        ansi("bold", "-no-rlwrap") RS\
        ins(1, "Don't invoke `rlwrap` when starting an interactive shell with `-I`.") RS\
        ansi("bold", "-E, -emacs") RS\
        ins(1, "Start an interactive shell within GNU Emacs, invoking `emacs`.") RS\
        ansi("bold", "-prompt [prompt_string]") RS\
        ins(1, "Customize your prompt string in the interactive shell.") RS\
        ansi("bold", "-prompt-color [color_code]") RS\
        ins(1, "Customize your prompt color in the interactive shell.") RS\
        ansi("bold", "-i [file], -input [file]") RS\
        ins(1, "Specify the input file name.") RS\
        ansi("bold", "-o [file], -output [file]") RS\
        ins(1, "Specify the output file name.") RS\
        ansi("bold", "-l [code], -lang [code]") RS\
        ins(1, "Specify your own, native language (\"home/host language\").") RS\
        ansi("bold", "-s [code], -source [code]") RS\
        ins(1, "Specify the source language (language of the original text).") RS\
        ansi("bold", "-t [codes], -target [codes]") RS\
        ins(1, "Specify the target language(s) (language(s) of the translated text).") RS\
        RS "See the man page " Command "(1) for more information."
}
function plTokenize(returnTokens, string,
                    delimiters,
                    newlines,
                    quotes,
                    escapeChars,
                    leftBlockComments,
                    rightBlockComments,
                    lineComments,
                    reservedOperators,
                    reservedPatterns,
                    blockCommenting,
                    c,
                    currentToken,
                    escaping,
                    i,
                    lineCommenting,
                    p,
                    quoting,
                    r,
                    s,
                    tempGroup,
                    tempPattern,
                    tempString) {
    if (!delimiters[0]) {
        delimiters[0] = " "
        delimiters[1] = "\t"
        delimiters[2] = "\v"
    }
    if (!newlines[0]) {
        newlines[0] = "\n"
        newlines[1] = "\r"
    }
    if (!quotes[0]) {
        quotes[0] = "\""
    }
    if (!escapeChars[0]) {
        escapeChars[0] = "\\"
    }
    if (!leftBlockComments[0]) {
        leftBlockComments[0] = "#|"
        leftBlockComments[1] = "/*"
        leftBlockComments[2] = "(*"
    }
    if (!rightBlockComments[0]) {
        rightBlockComments[0] = "|#"
        rightBlockComments[1] = "*/"
        rightBlockComments[2] = "*)"
    }
    if (!lineComments[0]) {
        lineComments[0] = ";"
        lineComments[1] = "//"
        lineComments[2] = "#"
    }
    if (!reservedOperators[0]) {
        reservedOperators[0] = "("
        reservedOperators[1] = ")"
        reservedOperators[2] = "["
        reservedOperators[3] = "]"
        reservedOperators[4] = "{"
        reservedOperators[5] = "}"
        reservedOperators[6] = ","
    }
    if (!reservedPatterns[0]) {
        reservedPatterns[0] = "[+-]?((0|[1-9][0-9]*)|[.][0-9]*|(0|[1-9][0-9]*)[.][0-9]*)([Ee][+-]?[0-9]+)?"
        reservedPatterns[1] = "[+-]?0[0-7]+([.][0-7]*)?"
        reservedPatterns[2] = "[+-]?0[Xx][0-9A-Fa-f]+([.][0-9A-Fa-f]*)?"
    }
    split(string, s, "")
    currentToken = ""
    quoting = escaping = blockCommenting = lineCommenting = 0
    p = 0
    i = 1
    while (i <= length(s)) {
        c = s[i]
        r = substr(string, i)
        if (blockCommenting) {
            if (tempString = startsWithAny(r, rightBlockComments))
                blockCommenting = 0
            i++
        } else if (lineCommenting) {
            if (belongsTo(c, newlines))
                lineCommenting = 0
            i++
        } else if (quoting) {
            currentToken = currentToken c
            if (escaping) {
                escaping = 0
            } else {
                if (belongsTo(c, quotes)) {
                    if (currentToken) {
                        returnTokens[p++] = currentToken
                        currentToken = ""
                    }
                    quoting = 0
                } else if (belongsTo(c, escapeChars)) {
                    escaping = 1
                } else {
                }
            }
            i++
        } else {
            if (belongsTo(c, delimiters) || belongsTo(c, newlines)) {
                if (currentToken) {
                    returnTokens[p++] = currentToken
                    currentToken = ""
                }
                i++
            } else if (belongsTo(c, quotes)) {
                if (currentToken) {
                    returnTokens[p++] = currentToken
                }
                currentToken = c
                quoting = 1
                i++
            } else if (tempString = startsWithAny(r, leftBlockComments)) {
                if (currentToken) {
                    returnTokens[p++] = currentToken
                    currentToken = ""
                }
                blockCommenting = 1
                i += length(tempString)
            } else if (tempString = startsWithAny(r, lineComments)) {
                if (currentToken) {
                    returnTokens[p++] = currentToken
                    currentToken = ""
                }
                lineCommenting = 1
                i += length(tempString)
            } else if (tempString = startsWithAny(r, reservedOperators)) {
                if (currentToken) {
                    returnTokens[p++] = currentToken
                    currentToken = ""
                }
                returnTokens[p++] = tempString
                i += length(tempString)
            } else if (tempPattern = matchesAny(r, reservedPatterns)) {
                if (currentToken) {
                    returnTokens[p++] = currentToken
                    currentToken = ""
                }
                match(r, "^" tempPattern, tempGroup)
                returnTokens[p++] = tempGroup[0]
                i += length(tempGroup[0])
            } else {
                currentToken = currentToken c
                i++
            }
        }
    }
    if (currentToken)
        returnTokens[p++] = currentToken
}
function plParse(returnAST, tokens,
                 leftBrackets,
                 rightBrackets,
                 separators,
                 i, j, key, p, stack, token) {
    if (!leftBrackets[0]) {
        leftBrackets[0] = "("
        leftBrackets[1] = "["
        leftBrackets[2] = "{"
    }
    if (!rightBrackets[0]) {
        rightBrackets[0] = ")"
        rightBrackets[1] = "]"
        rightBrackets[2] = "}"
    }
    if (!separators[0]) {
        separators[0] = ","
    }
    stack[p = 0] = 0
    for (i = 0; i < length(tokens); i++) {
        token = tokens[i]
        if (belongsTo(token, leftBrackets))
            stack[++p] = 0
        else if (belongsTo(token, rightBrackets))
            --p
        else if (belongsTo(token, separators))
            stack[p]++
        else {
            key = stack[0]
            for (j = 1; j <= p; j++)
                key = key SUBSEP stack[j]
            returnAST[key] = token
        }
    }
}
function initAudioPlayer() {
    AudioPlayer = !system("mplayer" SUPOUT SUPERR) ?
        "mplayer" :
        (!system("mpv" SUPOUT SUPERR) ?
         "mpv" :
         (!system("mpg123 --version" SUPOUT SUPERR) ?
          "mpg123" :
          ""))
}
function initSpeechSynthesizer() {
    SpeechSynthesizer = !system("say ''" SUPOUT SUPERR) ?
        "say" :
        (!system("espeak ''" SUPOUT SUPERR) ?
         "espeak" :
         "")
}
function initHttpService() {
    HttpProtocol = "http://"
    HttpHost = "translate.google.com"
    HttpPort = 80
    if (Option["proxy"]) {
        match(Option["proxy"], /^(http:\/*)?([^\/]*):([^\/:]*)/, HttpProxySpec)
        HttpService = "/inet/tcp/0/" HttpProxySpec[2] "/" HttpProxySpec[3]
        HttpPathPrefix = HttpProtocol HttpHost
    } else {
        HttpService = "/inet/tcp/0/" HttpHost "/" HttpPort
        HttpPathPrefix = ""
    }
}
function preprocess(text) {
    return quote(text)
}
function postprocess(text) {
    text = gensub(/ ([.,;:?!"])/, "\\1", "g", text)
    text = gensub(/(["]) /, "\\1", "g", text)
    return text
}
function getResponse(text, sl, tl, hl,    content, url) {
    url = HttpPathPrefix "/translate_a/single?client=t"\
        "&ie=UTF-8&oe=UTF-8"\
        "&dt=bd&dt=ex&dt=ld&dt=md&dt=qca&dt=rw&dt=rm&dt=ss&dt=t&dt=at"\
        "&q=" preprocess(text) "&sl=" sl "&tl=" tl "&hl=" hl
    print "GET " url " HTTP/1.1\n"\
          "Host: " HttpHost "\n"\
          "Connection: close\n" |& HttpService
    while ((HttpService |& getline) > 0)
        content = $0
    close(HttpService)
    return assert(content, "[ERROR] Null response.")
}
function play(text, tl,    url) {
    url = HttpProtocol HttpHost "/translate_tts?ie=UTF-8"\
        "&tl=" tl "&q=" preprocess(text)
    system(Option["player"] " " parameterize(url) SUPOUT SUPERR)
}
function getTranslation(text, sl, tl, hl,
                        isVerbose, toSpeech, returnPlaylist,
                        r,
                        content, tokens, ast,
                        il, ils, isPhonetic,
                        article, example, explanation, ref, word,
                        translation, translations, phonetics,
                        wordClasses, words, segments, altTranslations,
                        original, oPhonetics, oWordClasses, oWords,
                        oRefs, oSynonyms, oExamples, oSeeAlso,
                        wShowOriginal, wShowOriginalPhonetics,
                        wShowTranslation, wShowTranslationPhonetics,
                        wShowPromptMessage, wShowLanguages,
                        wShowOriginalDictionary, wShowDictionary,
                        wShowAlternatives,
                        hasWordClasses, hasAltTranslations,
                        i, j, k, group, temp, saveSortedIn) {
    isPhonetic = match(tl, /^@/)
    tl = substr(tl, 1 + isPhonetic)
    if (!getCode(tl)) {
        w("[WARNING] Unknown target language code: " tl)
    } else if (isRTL(tl)) {
        if (!FriBidi)
            w("[WARNING] " getName(tl) " is a right-to-left language, but FriBidi cannot be found.")
    }
    content = getResponse(text, sl, tl, hl)
    plTokenize(tokens, content)
    plParse(ast, tokens)
    if (Option["debug"]) {
        d(content)
        da(tokens, "tokens[%s]='%s'")
        da(ast, "ast[%s]='%s'")
    }
    if (!anything(ast)) {
        e("[ERROR] Oops! Something went wrong and I can't translate it for you :(")
        ExitCode = 1
        return
    }
    saveSortedIn = PROCINFO["sorted_in"]
    PROCINFO["sorted_in"] = "@ind_num_asc"
    for (i in ast) {
        if (i ~ "^0" SUBSEP "0" SUBSEP "[[:digit:]]+" SUBSEP "0$")
            append(translations, postprocess(literal(ast[i])))
        if (i ~ "^0" SUBSEP "0" SUBSEP "[[:digit:]]+" SUBSEP "1$")
            append(original, literal(ast[i]))
        if (i ~ "^0" SUBSEP "0" SUBSEP "[[:digit:]]+" SUBSEP "2$")
            append(phonetics, literal(ast[i]))
        if (i ~ "^0" SUBSEP "0" SUBSEP "[[:digit:]]+" SUBSEP "3$")
            append(oPhonetics, literal(ast[i]))
        if (match(i, "^0" SUBSEP "1" SUBSEP "([[:digit:]]+)" SUBSEP "0$", group))
            wordClasses[group[1]] = literal(ast[i])
        if (match(i, "^0" SUBSEP "1" SUBSEP "([[:digit:]]+)" SUBSEP "2" SUBSEP "([[:digit:]]+)" SUBSEP "([[:digit:]]+)$", group))
            words[group[1]][group[2]][group[3]] = literal(ast[i])
        if (match(i, "^0" SUBSEP "1" SUBSEP "([[:digit:]]+)" SUBSEP "2" SUBSEP "([[:digit:]]+)" SUBSEP "1" SUBSEP "([[:digit:]]+)$", group))
            words[group[1]][group[2]]["1"][group[3]] = literal(ast[i])
        if (match(i, "^0" SUBSEP "5" SUBSEP "([[:digit:]]+)" SUBSEP "0$", group)) {
            segments[group[1]] = literal(ast[i])
            altTranslations[group[1]][0] = ""
        }
        if (match(i, "^0" SUBSEP "5" SUBSEP "([[:digit:]]+)" SUBSEP "2" SUBSEP "([[:digit:]]+)" SUBSEP "0$", group))
            altTranslations[group[1]][group[2]] = postprocess(literal(ast[i]))
        if (i ~ "^0" SUBSEP "8" SUBSEP "0" SUBSEP "[[:digit:]]+$" ||
            i ~ "^0" SUBSEP "2$")
            append(ils, literal(ast[i]))
        if (match(i, "^0" SUBSEP "11" SUBSEP "([[:digit:]]+)" SUBSEP "0$", group))
            oWordClasses[group[1]] = literal(ast[i])
        if (match(i, "^0" SUBSEP "11" SUBSEP "([[:digit:]]+)" SUBSEP "1" SUBSEP "([[:digit:]]+)" SUBSEP "1$", group))
            if (ast[i]) {
                oRefs[literal(ast[i])][1] = group[1]
                oRefs[literal(ast[i])][2] = group[2]
            }
        if (match(i, "^0" SUBSEP "11" SUBSEP "([[:digit:]]+)" SUBSEP "1" SUBSEP "([[:digit:]]+)" SUBSEP "0" SUBSEP "([[:digit:]]+)$", group))
            oSynonyms[group[1]][group[2]][group[3]] = literal(ast[i])
        if (match(i, "^0" SUBSEP "12" SUBSEP "([[:digit:]]+)" SUBSEP "0$", group))
            oWordClasses[group[1]] = literal(ast[i])
        if (match(i, "^0" SUBSEP "12" SUBSEP "([[:digit:]]+)" SUBSEP "1" SUBSEP "([[:digit:]]+)" SUBSEP "0$", group))
            oWords[group[1]][group[2]][0] = literal(ast[i])
        if (match(i, "^0" SUBSEP "12" SUBSEP "([[:digit:]]+)" SUBSEP "1" SUBSEP "([[:digit:]]+)" SUBSEP "1$", group))
            oWords[group[1]][group[2]][1] = literal(ast[i])
        if (match(i, "^0" SUBSEP "12" SUBSEP "([[:digit:]]+)" SUBSEP "1" SUBSEP "([[:digit:]]+)" SUBSEP "2$", group))
            oWords[group[1]][group[2]][2] = postprocess(literal(ast[i]))
        if (match(i, "^0" SUBSEP "13" SUBSEP "0" SUBSEP "([[:digit:]]+)" SUBSEP "0$", group))
            oExamples[group[1]] = postprocess(literal(ast[i]))
        if (match(i, "^0" SUBSEP "14" SUBSEP "0" SUBSEP "([[:digit:]]+)$", group))
            oSeeAlso[group[1]] = literal(ast[i])
    }
    PROCINFO["sorted_in"] = saveSortedIn
    translation = join(translations)
    il = !anything(ils) || belongsTo(sl, ils) ? sl : ils[0]
    if (!isVerbose) {
        r = isPhonetic && anything(phonetics) ?
            join(phonetics) :
            s(translation, tl)
        if (toSpeech) {
            returnPlaylist[0]["text"] = translation
            returnPlaylist[0]["tl"] = tl
        }
    } else {
        wShowOriginal = Option["show-original"]
        wShowOriginalPhonetics = Option["show-original-phonetics"]
        wShowTranslation = Option["show-translation"]
        wShowTranslationPhonetics = Option["show-translation-phonetics"]
        wShowPromptMessage = Option["show-prompt-message"]
        wShowLanguages = Option["show-languages"]
        wShowOriginalDictionary = Option["show-original-dictionary"]
        wShowDictionary = Option["show-dictionary"]
        wShowAlternatives = Option["show-alternatives"]
        if (!anything(oPhonetics)) wShowOriginalPhonetics = 0
        if (!anything(phonetics)) wShowTranslationPhonetics = 0
        if (il == tl && isarray(oWordClasses)) {
            wShowOriginalDictionary = 1
            wShowTranslation = 0
        }
        hasWordClasses = isarray(wordClasses) && anything(wordClasses)
        hasAltTranslations = isarray(altTranslations[0]) && anything(altTranslations[0])
        if (!hasWordClasses) wShowDictionary = 0
        if (hasWordClasses || !hasAltTranslations) wShowAlternatives = 0
        if (wShowOriginal) {
            if (r) r = r RS RS
            r = r ansi("negative", ansi("bold", s(join(original), il)))
            if (wShowOriginalPhonetics)
                r = r RS showPhonetics(join(oPhonetics), il)
        }
        if (wShowTranslation) {
            if (r) r = r RS RS
            r = r ansi("bold", s(translation, tl))
            if (wShowTranslationPhonetics)
                r = r RS showPhonetics(join(phonetics), tl)
        }
        if (wShowPromptMessage || wShowLanguages)
            if (r) r = r RS
        if (wShowPromptMessage) {
            if (hasWordClasses) {
                if (r) r = r RS
                if (isRTL(hl))
                    r = r s(showDefinitionsOf(hl, join(original)))
                else
                    r = r showDefinitionsOf(hl, ansi("underline", show(join(original), il)))
            } else if (hasAltTranslations) {
                if (r) r = r RS
                if (isRTL(hl))
                    r = r s(showTranslationsOf(hl, join(original)))
                else
                    r = r showTranslationsOf(hl, ansi("underline", show(join(original), il)))
            }
        }
        if (wShowLanguages) {
            if (hasWordClasses || hasAltTranslations) {
                if (r) r = r RS
                r = r s(sprintf("[ %s -> %s ]", getEndonym(il), getEndonym(tl)))
            }
        }
        if (wShowOriginalDictionary) {
            if (r) r = r RS
            if (isarray(oWordClasses) && anything(oWordClasses)) {
                for (i = 0; i < length(oWordClasses); i++) {
                    r = (i > 0 ? r RS : r) RS s(oWordClasses[i], hl)
                    if (isarray(oWords[i])) {
                        for (j = 0; j < length(oWords[i]); j++) {
                            explanation = oWords[i][j][0]
                            ref = oWords[i][j][1]
                            example = oWords[i][j][2]
                            r = (j > 0 ? r RS : r) RS ansi("bold", ins(1, explanation, il))
                            if (example)
                                r = r RS ins(2, "- \"" example "\"", il)
                            if (ref && isarray(oRefs[ref])) {
                                temp = showSynonyms(hl) ": " oSynonyms[oRefs[ref][1]][oRefs[ref][2]][0]
                                for (k = 1; k < length(oSynonyms[oRefs[ref][1]][oRefs[ref][2]]); k++)
                                    temp = temp ", " oSynonyms[oRefs[ref][1]][oRefs[ref][2]][k]
                                r = r RS ins(1, temp)
                            }
                        }
                    } else {
                        for (j = 0; j < length(oSynonyms[i]); j++) {
                            temp = "* " oSynonyms[i][j][0]
                            for (k = 1; k < length(oSynonyms[i][j]); k++)
                                temp = temp ", " oSynonyms[i][j][k]
                            r = r RS ins(1, temp)
                        }
                    }
                }
            }
            if (isarray(oExamples) && anything(oExamples)) {
                r = r RS RS s(showExamples(hl), hl)
                for (i = 0; i < length(oExamples); i++) {
                    example = oExamples[i]
                    if (isRTL(il)) {
                        sub(/\u003cb\u003e/, "", example)
                        sub(/\u003c\/b\u003e/, "", example)
                    } else {
                        sub(/\u003cb\u003e/, AnsiCode["negative"] AnsiCode["bold"], example)
                        sub(/\u003c\/b\u003e/, AnsiCode["positive"] AnsiCode["no bold"], example)
                    }
                    r = (i > 0 ? r RS : r) RS ins(1, "- " example, il)
                }
            }
            if (isarray(oSeeAlso) && anything(oSeeAlso)) {
                r = r RS RS s(showSeeAlso(hl), hl)
                temp = isRTL(il) ? oSeeAlso[0] : ansi("underline", oSeeAlso[0])
                for (k = 1; k < length(oSeeAlso); k++)
                    temp = temp ", " (isRTL(il) ? oSeeAlso[k] : ansi("underline", oSeeAlso[k]))
                r = r RS ins(1, temp, il)
            }
        }
        if (wShowDictionary) {
            if (r) r = r RS
            for (i = 0; i < length(wordClasses); i++) {
                r = (i > 0 ? r RS : r) RS s(wordClasses[i], hl)
                for (j = 0; j < length(words[i]); j++) {
                    word = words[i][j][0]
                    explanation = join(words[i][j][1], ", ")
                    article = words[i][j][4]
                    r = r RS ansi("bold", ins(1, (article ? "(" article ") " : "") word, tl))
                    r = r RS ins(2, explanation, il)
                }
            }
        }
        if (wShowAlternatives) {
            if (r) r = r RS RS
            for (i = 0; i < length(altTranslations); i++) {
                r = (i > 0 ? r RS : r) ansi("underline", show(segments[i]))
                temp = isRTL(tl) ? altTranslations[i][0] : ansi("bold", altTranslations[i][0])
                for (j = 1; j < length(altTranslations[i]); j++)
                    temp = temp ", " (isRTL(tl) ? altTranslations[i][j] : ansi("bold", altTranslations[i][j]))
                r = r RS ins(1, temp)
            }
        }
        if (toSpeech) {
            if (index(showTranslationsOf(hl, "%s"), "%s") > 2) {
                returnPlaylist[0]["text"] = showTranslationsOf(hl)
                returnPlaylist[0]["tl"] = hl
                returnPlaylist[1]["text"] = join(original)
                returnPlaylist[1]["tl"] = il
            } else {
                returnPlaylist[0]["text"] = join(original)
                returnPlaylist[0]["tl"] = il
                returnPlaylist[1]["text"] = showTranslationsOf(hl)
                returnPlaylist[1]["tl"] = hl
            }
            returnPlaylist[2]["text"] = translation
            returnPlaylist[2]["tl"] = tl
        }
    }
    return r
}
function fileTranslation(uri,    group, temp1, temp2) {
    temp1 = Option["input"]
    temp2 = Option["verbose"]
    match(uri, /^file:\/\/(.*)/, group)
    Option["input"] = group[1]
    Option["verbose"] = 0
    translateMain()
    Option["input"] = temp1
    Option["verbose"] = temp2
}
function webTranslation(uri, sl, tl, hl) {
    system(Option["browser"] " " parameterize("https://translate.google.com/translate?"\
                                              "hl=" hl "&sl=" sl "&tl=" tl "&u=" uri) "&")
}
function translate(text, inline,
                   i, j, r, playlist, saveSortedIn) {
    if (!getCode(Option["hl"])) {
        w("[WARNING] Unknown language code: " Option["hl"] ", fallback to English: en")
        Option["hl"] = "en"
    } else if (isRTL(Option["hl"])) {
        if (!FriBidi)
            w("[WARNING] " getName(Option["hl"]) " is a right-to-left language, but FriBidi cannot be found.")
    }
    if (!getCode(Option["sl"])) {
        w("[WARNING] Unknown source language code: " Option["sl"])
    } else if (isRTL(Option["sl"])) {
        if (!FriBidi)
            w("[WARNING] " getName(Option["sl"]) " is a right-to-left language, but FriBidi cannot be found.")
    }
    saveSortedIn = PROCINFO["sorted_in"]
    PROCINFO["sorted_in"] = "@ind_num_asc"
    for (i in Option["tl"]) {
        if (!Option["interactive"])
            if (Option["verbose"] && i > 1)
                print replicate("─", Option["width"])
        if (inline &&
            startsWithAny(text, UriSchemes) == "file://") {
            fileTranslation(text)
        } else if (inline &&
                   startsWithAny(text, UriSchemes) == "http://" ||
                   startsWithAny(text, UriSchemes) == "https://") {
            webTranslation(text, Option["sl"], Option["tl"][i], Option["hl"])
        } else {
            r = getTranslation(text, Option["sl"], Option["tl"][i], Option["hl"], Option["verbose"], Option["play"], playlist)
            print r > Option["output"]
            if (Option["play"])
                if (Option["player"])
                    for (j in playlist)
                        play(playlist[j]["text"], playlist[j]["tl"])
                else if (SpeechSynthesizer)
                    for (j in playlist)
                        print playlist[j]["text"] | SpeechSynthesizer
        }
    }
    PROCINFO["sorted_in"] = saveSortedIn
}
function translateMain(    i, line) {
    if (Option["interactive"])
        prompt()
    i = 0
    while (getline line < Option["input"]) {
        if (!Option["interactive"])
            if (Option["verbose"] && i++ > 0)
                print replicate("═", Option["width"])
        if (Option["interactive"]) {
            if (line ~ /:(q|quit)/)
                exit
            else if (line ~ /:(s|source)/)
                print Option["sl"]
            else if (line ~ /:(t|target)/) {
                printf "(" Option["tl"][1]
                for (i = 2; i <= length(Option["tl"]); i++)
                    printf ", " Option["tl"][i]
                print ")"
            }
            else {
                translate(line)
                if (Option["verbose"]) printf RS
            }
            prompt()
        } else
            translate(line)
    }
}
function initRlwrap() {
    Rlwrap = ("rlwrap --version" SUPERR | getline) ? "rlwrap" : ""
}
function prompt(    i, p, temp) {
    p = Option["prompt"]
    if (p ~ /%a/) gsub(/%a/, strftime("%a"), p)
    if (p ~ /%A/) gsub(/%A/, strftime("%A"), p)
    if (p ~ /%b/) gsub(/%b/, strftime("%b"), p)
    if (p ~ /%B/) gsub(/%B/, strftime("%B"), p)
    if (p ~ /%c/) gsub(/%c/, strftime("%c"), p)
    if (p ~ /%C/) gsub(/%C/, strftime("%C"), p)
    if (p ~ /%d/) gsub(/%d/, strftime("%d"), p)
    if (p ~ /%D/) gsub(/%D/, strftime("%D"), p)
    if (p ~ /%e/) gsub(/%e/, strftime("%e"), p)
    if (p ~ /%F/) gsub(/%F/, strftime("%F"), p)
    if (p ~ /%g/) gsub(/%g/, strftime("%g"), p)
    if (p ~ /%G/) gsub(/%G/, strftime("%G"), p)
    if (p ~ /%h/) gsub(/%h/, strftime("%h"), p)
    if (p ~ /%H/) gsub(/%H/, strftime("%H"), p)
    if (p ~ /%I/) gsub(/%I/, strftime("%I"), p)
    if (p ~ /%j/) gsub(/%j/, strftime("%j"), p)
    if (p ~ /%m/) gsub(/%m/, strftime("%m"), p)
    if (p ~ /%M/) gsub(/%M/, strftime("%M"), p)
    if (p ~ /%n/) gsub(/%n/, strftime("%n"), p)
    if (p ~ /%p/) gsub(/%p/, strftime("%p"), p)
    if (p ~ /%r/) gsub(/%r/, strftime("%r"), p)
    if (p ~ /%R/) gsub(/%R/, strftime("%R"), p)
    if (p ~ /%u/) gsub(/%u/, strftime("%u"), p)
    if (p ~ /%U/) gsub(/%U/, strftime("%U"), p)
    if (p ~ /%V/) gsub(/%V/, strftime("%V"), p)
    if (p ~ /%w/) gsub(/%w/, strftime("%w"), p)
    if (p ~ /%W/) gsub(/%W/, strftime("%W"), p)
    if (p ~ /%x/) gsub(/%x/, strftime("%x"), p)
    if (p ~ /%X/) gsub(/%X/, strftime("%X"), p)
    if (p ~ /%y/) gsub(/%y/, strftime("%y"), p)
    if (p ~ /%Y/) gsub(/%Y/, strftime("%Y"), p)
    if (p ~ /%z/) gsub(/%z/, strftime("%z"), p)
    if (p ~ /%Z/) gsub(/%Z/, strftime("%Z"), p)
    if (p ~ /%_/)
        gsub(/%_/, showTranslationsOf(Option["hl"]), p)
    if (p ~ /%l/)
        gsub(/%l/, getDisplay(Option["hl"]), p)
    if (p ~ /%L/)
        gsub(/%L/, getName(Option["hl"]), p)
    if (p ~ /%S/)
        gsub(/%S/, getName(Option["sl"]), p)
    if (p ~ /%t/) {
        temp = getDisplay(Option["tl"][1])
        for (i = 2; i <= length(Option["tl"]); i++)
            temp = temp "+" getDisplay(Option["tl"][i])
        gsub(/%t/, temp, p)
    }
    if (p ~ /%T/) {
        temp = getName(Option["tl"][1])
        for (i = 2; i <= length(Option["tl"]); i++)
            temp = temp "+" getName(Option["tl"][i])
        gsub(/%T/, temp, p)
    }
    if (p ~ /%,/) {
        temp = getDisplay(Option["tl"][1])
        for (i = 2; i <= length(Option["tl"]); i++)
            temp = temp "," getDisplay(Option["tl"][i])
        gsub(/%,/, temp, p)
    }
    if (p ~ /%</) {
        temp = getName(Option["tl"][1])
        for (i = 2; i <= length(Option["tl"]); i++)
            temp = temp "," getName(Option["tl"][i])
        gsub(/%</, temp, p)
    }
    if (p ~ /%\//) {
        temp = getDisplay(Option["tl"][1])
        for (i = 2; i <= length(Option["tl"]); i++)
            temp = temp "/" getDisplay(Option["tl"][i])
        gsub(/%\//, temp, p)
    }
    if (p ~ /%\?/) {
        temp = getName(Option["tl"][1])
        for (i = 2; i <= length(Option["tl"]); i++)
            temp = temp "/" getName(Option["tl"][i])
        gsub(/%\?/, temp, p)
    }
    printf(AnsiCode["bold"] AnsiCode[tolower(Option["prompt-color"])] p AnsiCode[0] " ", getDisplay(Option["sl"])) > STDERR
}

function initGawk(    group) {
    Gawk = "gawk"
    GawkVersion = PROCINFO["version"]
    split(PROCINFO["version"], group, ".")
    if (group[1] < 4) {
        e("[ERROR] Oops! Your gawk (version " GawkVersion ") "\
          "appears to be too old.\n"\
          "        You need at least gawk 4.0.0 to run this program.")
        exit 1
    }
}
function init1() {
    initGawk()
    initBiDi()
    initLocale()
    initLocaleDisplay()
    initUserLang()
    RS = "\n"
    ExitCode = 0
    Option["debug"] = 0
    Option["verbose"] = 1
    Option["show-original"] = 1
    Option["show-original-phonetics"] = 1
    Option["show-translation"] = 1
    Option["show-translation-phonetics"] = 1
    Option["show-prompt-message"] = 1
    Option["show-languages"] = 1
    Option["show-original-dictionary"] = 0
    Option["show-dictionary"] = 1
    Option["show-alternatives"] = 1
    Option["width"] = ENVIRON["COLUMNS"] ? ENVIRON["COLUMNS"] : 64
    Option["indent"] = 4
    Option["browser"] = ENVIRON["BROWSER"]
    Option["play"] = 0
    Option["player"] = ENVIRON["PLAYER"]
    Option["proxy"] = ENVIRON["HTTP_PROXY"] ? ENVIRON["HTTP_PROXY"] : ENVIRON["http_proxy"]
    Option["interactive"] = 0
    Option["no-rlwrap"] = 0
    Option["emacs"] = 0
    Option["prompt"] = ENVIRON["TRANS_PS"] ? ENVIRON["TRANS_PS"] : "%s>"
    Option["prompt-color"] = ENVIRON["TRANS_PS_COLOR"] ? ENVIRON["TRANS_PS_COLOR"] : "default"
    Option["input"] = ""
    Option["output"] = STDOUT
    Option["hl"] = ENVIRON["HOME_LANG"] ? ENVIRON["HOME_LANG"] : UserLang
    Option["sl"] = ENVIRON["SOURCE_LANG"] ? ENVIRON["SOURCE_LANG"] : "auto"
    Option["tl"][1] = ENVIRON["TARGET_LANG"] ? ENVIRON["TARGET_LANG"] : UserLang
}
function init2() {
    if (Option["no-ansi"])
        delete AnsiCode
}
function init3(    group) {
    initHttpService()
    if (!Option["browser"]) {
        "xdg-mime query default text/html" SUPERR |& getline Option["browser"]
        match(Option["browser"], "(.*).desktop$", group)
        Option["browser"] = group[1]
    }
    if (Option["play"]) {
        if (!Option["player"]) {
            initAudioPlayer()
            Option["player"] = AudioPlayer ? AudioPlayer : Option["player"]
            if (!Option["player"])
                initSpeechSynthesizer()
        }
        if (!Option["player"] && !SpeechSynthesizer) {
            w("[WARNING] No available audio player or speech synthesizer is found.")
            Option["play"] = 0
        }
    }
}
BEGIN {
    init1()
    pos = 0
    while (ARGV[++pos]) {
        match(ARGV[pos], /^-(-?no-op)?$/)
        if (RSTART) continue
        match(ARGV[pos], /^--?(vers(i(on?)?)?|V)$/)
        if (RSTART) {
            print getVersion()
            print
            printf("%-22s%s\n", "gawk (GNU Awk)", PROCINFO["version"])
            printf("%s\n", FriBidi ? FriBidi : "fribidi (GNU FriBidi) [NOT INSTALLED]")
            printf("%-22s%s\n", "User Language", getName(UserLang) " (" getDisplay(UserLang) ")")
            exit
        }
        match(ARGV[pos], /^--?(h(e(lp?)?)?|H)$/)
        if (RSTART) {
            print getHelp()
            exit
        }
        match(ARGV[pos], /^--?(m(a(n(u(al?)?)?)?)?|M)$/)
        if (RSTART) {
            if (ENVIRON["TRANS_MANPAGE"])
                system("echo -E \"${TRANS_MANPAGE}\" | "\
                       "groff -Wall -mtty-char -mandoc -Tutf8 -rLL=${COLUMNS}n -rLT=${COLUMNS}n | "\
                       (system("most" SUPERR) ?
                        "less -s -P\"\\ \\Manual page " Command "(1) line %lt (press h for help or q to quit)\"" :
                        "most -Cs"))
            else
                print getHelp()
            exit
        }
        match(ARGV[pos], /^--?r(e(f(e(r(e(n(ce?)?)?)?)?)?)?)?$/)
        if (RSTART) {
            print getReference("endonym")
            exit
        }
        match(ARGV[pos], /^--?(reference-(e(n(g(l(i(sh?)?)?)?)?)?)?|R)$/)
        if (RSTART) {
            print getReference("name")
            exit
        }
        match(ARGV[pos], /^--?(debug|D)$/)
        if (RSTART) {
            Option["debug"] = 1
            continue
        }
        match(ARGV[pos], /^--?v(e(r(b(o(se?)?)?)?)?)?$/)
        if (RSTART) {
            Option["verbose"] = 1
            continue
        }
        match(ARGV[pos], /^--?b(r(i(ef?)?)?)?$/)
        if (RSTART) {
            Option["verbose"] = 0
            continue
        }
        match(ARGV[pos], /^--?show-original(=(.*)?)?$/, group)
        if (RSTART) {
            Option["show-original"] = yn(group[1] ? group[2] : ARGV[++pos])
            continue
        }
        match(ARGV[pos], /^--?show-original-phonetics(=(.*)?)?$/, group)
        if (RSTART) {
            Option["show-original-phonetics"] = yn(group[1] ? group[2] : ARGV[++pos])
            continue
        }
        match(ARGV[pos], /^--?show-translation(=(.*)?)?$/, group)
        if (RSTART) {
            Option["show-translation"] = yn(group[1] ? group[2] : ARGV[++pos])
            continue
        }
        match(ARGV[pos], /^--?show-translation-phonetics(=(.*)?)?$/, group)
        if (RSTART) {
            Option["show-translation-phonetics"] = yn(group[1] ? group[2] : ARGV[++pos])
            continue
        }
        match(ARGV[pos], /^--?show-prompt-message(=(.*)?)?$/, group)
        if (RSTART) {
            Option["show-prompt-message"] = yn(group[1] ? group[2] : ARGV[++pos])
            continue
        }
        match(ARGV[pos], /^--?show-languages(=(.*)?)?$/, group)
        if (RSTART) {
            Option["show-languages"] = yn(group[1] ? group[2] : ARGV[++pos])
            continue
        }
        match(ARGV[pos], /^--?show-original-dictionary(=(.*)?)?$/, group)
        if (RSTART) {
            Option["show-original-dictionary"] = yn(group[1] ? group[2] : ARGV[++pos])
            continue
        }
        match(ARGV[pos], /^--?show-dictionary(=(.*)?)?$/, group)
        if (RSTART) {
            Option["show-dictionary"] = yn(group[1] ? group[2] : ARGV[++pos])
            continue
        }
        match(ARGV[pos], /^--?show-alternatives(=(.*)?)?$/, group)
        if (RSTART) {
            Option["show-alternatives"] = yn(group[1] ? group[2] : ARGV[++pos])
            continue
        }
        match(ARGV[pos], /^--?no-ansi/)
        if (RSTART) {
            Option["no-ansi"] = 1
            continue
        }
        match(ARGV[pos], /^--?w(i(d(th?)?)?)?(=(.*)?)?$/, group)
        if (RSTART) {
            Option["width"] = group[4] ?
                (group[5] ? group[5] : Option["width"]) :
                ARGV[++pos]
            continue
        }
        match(ARGV[pos], /^--?indent(=(.*)?)?$/, group)
        if (RSTART) {
            Option["indent"] = group[1] ?
                (group[2] ? group[2] : Option["indent"]) :
                ARGV[++pos]
            continue
        }
        match(ARGV[pos], /^--?browser(=(.*)?)?$/, group)
        if (RSTART) {
            Option["browser"] = group[1] ?
                (group[2] ? group[2] : Option["browser"]) :
                ARGV[++pos]
            continue
        }
        match(ARGV[pos], /^--?p(l(ay?)?)?$/)
        if (RSTART) {
            Option["play"] = 1
            continue
        }
        match(ARGV[pos], /^--?player(=(.*)?)?$/, group)
        if (RSTART) {
            Option["play"] = 1
            Option["player"] = group[1] ?
                (group[2] ? group[2] : Option["player"]) :
                ARGV[++pos]
            continue
        }
        match(ARGV[pos], /^--?(proxy|x)(=(.*)?)?$/, group)
        if (RSTART) {
            Option["proxy"] = group[2] ?
                (group[3] ? group[3] : Option["proxy"]) :
                ARGV[++pos]
            continue
        }
        match(ARGV[pos], /^--?(int(e(r(a(c(t(i(ve?)?)?)?)?)?)?)?|I)$/)
        if (RSTART) {
            Option["interactive"] = 1
            continue
        }
        match(ARGV[pos], /^--?no-rlwrap/)
        if (RSTART) {
            Option["no-rlwrap"] = 1
            continue
        }
        match(ARGV[pos], /^--?(emacs|E)$/)
        if (RSTART) {
            Option["emacs"] = 1
            continue
        }
        match(ARGV[pos], /^--?prompt(=(.*)?)?$/, group)
        if (RSTART) {
            Option["prompt"] = group[1] ?
                (group[2] ? group[2] : Option["prompt"]) :
                ARGV[++pos]
            continue
        }
        match(ARGV[pos], /^--?prompt-color(=(.*)?)?$/, group)
        if (RSTART) {
            Option["prompt-color"] = group[1] ?
                (group[2] ? group[2] : Option["prompt-color"]) :
                ARGV[++pos]
            continue
        }
        match(ARGV[pos], /^--?i(n(p(ut?)?)?)?(=(.*)?)?$/, group)
        if (RSTART) {
            Option["input"] = group[4] ?
                (group[5] ? group[5] : Option["input"]) :
                ARGV[++pos]
            continue
        }
        match(ARGV[pos], /^--?o(u(t(p(ut?)?)?)?)?(=(.*)?)?$/, group)
        if (RSTART) {
            Option["output"] = group[5] ?
                (group[6] ? group[6] : Option["output"]) :
                ARGV[++pos]
            continue
        }
        match(ARGV[pos], /^--?l(a(ng?)?)?(=(.*)?)?$/, group)
        if (RSTART) {
            Option["hl"] = group[3] ?
                (group[4] ? group[4] : Option["hl"]) :
                ARGV[++pos]
            continue
        }
        match(ARGV[pos], /^--?s(o(u(r(ce?)?)?)?)?(=(.*)?)?$/, group)
        if (RSTART) {
            Option["sl"] = group[5] ?
                (group[6] ? group[6] : Option["sl"]) :
                ARGV[++pos]
            continue
        }
        match(ARGV[pos], /^--?t(a(r(g(et?)?)?)?)?(=(.*)?)?$/, group)
        if (RSTART) {
            if (group[5]) {
                if (group[6]) split(group[6], Option["tl"], "+")
            } else
                split(ARGV[++pos], Option["tl"], "+")
            continue
        }
        match(ARGV[pos], /^[{(\[]?([[:alpha:]][[:alpha:]][[:alpha:]]?(-[[:alpha:]][[:alpha:]])?)?(:|=)((@?[[:alpha:]][[:alpha:]][[:alpha:]]?(-[[:alpha:]][[:alpha:]])?\+)*(@?[[:alpha:]][[:alpha:]][[:alpha:]]?(-[[:alpha:]][[:alpha:]])?)?)[})\]]?$/, group)
        if (RSTART) {
            if (group[1]) Option["sl"] = group[1]
            if (group[4]) split(group[4], Option["tl"], "+")
            continue
        }
        match(ARGV[pos], /^--$/)
        if (RSTART) {
            ++pos
            break
        }
        break
    }
    init2()
    if (Option["interactive"] && !Option["no-rlwrap"]) {
        initRlwrap()
        if (Rlwrap && (ENVIRON["TRANS_PROGRAM"] || fileExists(EntryPoint))) {
            command = Rlwrap " " Gawk " " (ENVIRON["TRANS_PROGRAM"] ?
                                           "\"${TRANS_PROGRAM}\"" :
                                           "-f " EntryPoint) " -"\
                " -no-rlwrap"
            for (i = 1; i < length(ARGV); i++)
                if (ARGV[i])
                    command = command " " parameterize(ARGV[i])
            if (!system(command))
                exit
            else
                ;
        } else
            ;
    } else if (!Option["interactive"] && !Option["no-rlwrap"] && Option["emacs"]) {
        Emacs = "emacs"
        if (ENVIRON["TRANS_PROGRAM"] || fileExists(EntryPoint)) {
            params = ""
            for (i = 1; i < length(ARGV); i++)
                if (ARGV[i])
                    params = params " " (parameterize(ARGV[i], "\""))
            if (ENVIRON["TRANS_PROGRAM"]) {
                el = "(progn (setq trans-program (getenv \"TRANS_PROGRAM\")) "\
                    "(setq explicit-shell-file-name \"" Gawk "\") "\
                    "(setq explicit-" Gawk "-args (cons trans-program '(\"-\" \"-I\" \"-no-rlwrap\"" params "))) "\
                    "(command-execute 'shell) (rename-buffer \"" Name "\"))"
            } else {
                el = "(progn (setq explicit-shell-file-name \"" Gawk "\") "\
                    "(setq explicit-" Gawk "-args '(\"-f\" \"" EntryPoint "\" \"--\" \"-I\" \"-no-rlwrap\"" params ")) "\
                    "(command-execute 'shell) (rename-buffer \"" Name "\"))"
            }
            command = Emacs " --eval " parameterize(el)
            if (!system(command))
                exit
            else
                Option["interactive"] = 1
        } else
            Option["interactive"] = 1
    }
    if (Option["interactive"]) {
        print AnsiCode["bold"] AnsiCode[tolower(Option["prompt-color"])] getVersion() AnsiCode[0] > STDERR
        print AnsiCode[tolower(Option["prompt-color"])] "(:q to quit)" AnsiCode[0] > STDERR
    }
    init3()
    if (pos < ARGC) {
        for (i = pos; i < ARGC; i++) {
            if (Option["verbose"] && i > pos)
                print replicate("═", Option["width"])
            translate(ARGV[i], 1)
        }
    } else {
        if (!Option["input"]) Option["input"] = STDIN
    }
    if (Option["input"])
        translateMain()
    exit ExitCode
}