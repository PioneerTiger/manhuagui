local tf_utils = require "tf_api.utils"
tf_utils.init_plugin("manhuagui")
local debug = require "tf_api.debug"
local http = require "tf_api.http"

local M = {}

local lock = false

function M.search(act)
    local query = {
        keyword = act.payload.keyword,
        page = act.payload.page + 1,
        allow_cache=false
    }

    local url = 'https://api-manhuagui.aoihosizora.top/v1/' .. 'search'
    local ret = http.get(url, {
        query = query
    })

    if ret.code ~= 200 then
        return {
            success = false,
            data = {}
        }
    end

    local json_ret = dart_json.decode(ret.content)
    dart_utils.log('search result:'.. debug.debug_table(json_ret))

    local rets = {}

    for _, item in ipairs(json_ret.data.data) do
        local data = {
            title = item.title,
            cover = item.cover,
            comic_id = tostring(item.mid),
            extra = item
        }
        table.insert(rets, data)
    end

    local nomore = false
    if json_ret.data.page * json_ret.data.limit >= json_ret.data.total then
        nomore = true
    end

    return {
        success = true,
        nomore = nomore,
        data = rets
    }
end


function M.download_image(act)
    while lock do
        tf_utils.delay(300)
    end

    lock = true

    local url = act.payload.url
    local path = act.payload.downloadPath
    local headers = {
        accept = 'image/webp,image/apng,image/*,*/*;q=0.8',
        ['accept-encoding'] = 'gzip, deflate, br',
        ['accept-language'] = 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7,zh-CN;q=0.6',
        ['cache-control'] = 'no-cache',
        ['pragma'] = 'no-cache',
        ['referer'] = 'https://www.manhuagui.com/',
        ['sec-fetch-dest'] = 'image',
        ['sec-fetch-mode'] = 'no-cors',
        ['sec-fetch-site'] = 'cross-site',
        ['user-agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.129 Safari/537.36'
    }

    local now = dart_os_ext.now()

    local response = http.download(url, path, {
        headers = headers
    })

    local ms = dart_os_ext.get_duration_ms(now)
    dart_utils.log('download image cost:' .. tostring(ms))
    local delay_time = 500 - ms
    if delay_time > 0 then
        tf_utils.delay(delay_time)
    end

    lock = false

    return {
        code = response.code,
    }
end

function M.get_detail(act)
    local url = 'https://api-manhuagui.aoihosizora.top/v1/' .. 'manga/' .. act.payload.comic_id
    local query = {
        allow_cache = false
    }
    local ret = http.get(url, {
        query = query
    })

    if ret.code ~= 200 then
        print('error response', ret.code)
        return {}
    end

    local json_ret = dart_json.decode(ret.content)
    local chapters = {}
    for _, item in ipairs(json_ret.data.chapter_groups) do
        for _, chapter in ipairs(item.chapters) do
            table.insert(chapters, {
                id = tostring(chapter.cid),
                title = chapter.title,
            })
        end
    end

    return {
        title = json_ret.data.title,
        cover = json_ret.data.cover,
        chapters = chapters,
        id = tostring(json_ret.data.mid),
        extra = json_ret.data
    }
end

function M.chapter_detail(act)
    local url = 'https://api-manhuagui.aoihosizora.top/v1/' .. 'manga/' .. act.payload.comic_id .. '/' .. act.payload.chapter_id
    local query = {
        allow_cache = false
    }
    local ret = http.get(url, {
        query = query
    })

    if ret.code ~= 200 then
        print('error response', ret.code)
        return {}
    end

    local json_ret = dart_json.decode(ret.content)

    local images = {}
    for _, item in ipairs(json_ret.data.pages) do
        table.insert(images, item)
    end

    return {
        images = images,
        extra = json_ret.data
    }
end

return M
