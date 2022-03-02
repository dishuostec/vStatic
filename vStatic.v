module main

import os
import flag
import io
import net
import net.http
import net.urllib
import time

const (
	headers_close = http.new_custom_header_from_map({
		'Server':                           'vStatic'
		http.CommonHeader.connection.str(): 'close'
	}) or { panic('should never fail') }

	http_400      = http.new_response(
		status: .bad_request
		text: '400 Bad Request'
		header: http.new_header(
			key: .content_type
			value: 'text/plain'
		).join(headers_close)
	)
	http_404      = http.new_response(
		status: .not_found
		text: '404 Not Found'
		header: http.new_header(
			key: .content_type
			value: 'text/plain'
		).join(headers_close)
	)
	http_405      = http.new_response(
		status: .method_not_allowed
		text: '405 Method Not Allowed'
		header: http.new_header(
			key: .content_type
			value: 'text/plain'
		).join(headers_close)
	)
	http_500      = http.new_response(
		status: .internal_server_error
		text: '500 Internal Server Error'
		header: http.new_header(
			key: .content_type
			value: 'text/plain'
		).join(headers_close)
	)
	mime_types    = {
		'.aac':    'audio/aac'
		'.abw':    'application/x-abiword'
		'.arc':    'application/x-freearc'
		'.avi':    'video/x-msvideo'
		'.azw':    'application/vnd.amazon.ebook'
		'.bin':    'application/octet-stream'
		'.bmp':    'image/bmp'
		'.bz':     'application/x-bzip'
		'.bz2':    'application/x-bzip2'
		'.cda':    'application/x-cdf'
		'.csh':    'application/x-csh'
		'.css':    'text/css'
		'.csv':    'text/csv'
		'.doc':    'application/msword'
		'.docx':   'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
		'.eot':    'application/vnd.ms-fontobject'
		'.epub':   'application/epub+zip'
		'.gz':     'application/gzip'
		'.gif':    'image/gif'
		'.htm':    'text/html'
		'.html':   'text/html'
		'.ico':    'image/vnd.microsoft.icon'
		'.ics':    'text/calendar'
		'.jar':    'application/java-archive'
		'.jpeg':   'image/jpeg'
		'.jpg':    'image/jpeg'
		'.js':     'text/javascript'
		'.json':   'application/json'
		'.jsonld': 'application/ld+json'
		'.mid':    'audio/midi audio/x-midi'
		'.midi':   'audio/midi audio/x-midi'
		'.mjs':    'text/javascript'
		'.mp3':    'audio/mpeg'
		'.mp4':    'video/mp4'
		'.mpeg':   'video/mpeg'
		'.mpkg':   'application/vnd.apple.installer+xml'
		'.odp':    'application/vnd.oasis.opendocument.presentation'
		'.ods':    'application/vnd.oasis.opendocument.spreadsheet'
		'.odt':    'application/vnd.oasis.opendocument.text'
		'.oga':    'audio/ogg'
		'.ogv':    'video/ogg'
		'.ogx':    'application/ogg'
		'.opus':   'audio/opus'
		'.otf':    'font/otf'
		'.png':    'image/png'
		'.pdf':    'application/pdf'
		'.php':    'application/x-httpd-php'
		'.ppt':    'application/vnd.ms-powerpoint'
		'.pptx':   'application/vnd.openxmlformats-officedocument.presentationml.presentation'
		'.rar':    'application/vnd.rar'
		'.rtf':    'application/rtf'
		'.sh':     'application/x-sh'
		'.svg':    'image/svg+xml'
		'.swf':    'application/x-shockwave-flash'
		'.tar':    'application/x-tar'
		'.tif':    'image/tiff'
		'.tiff':   'image/tiff'
		'.ts':     'video/mp2t'
		'.ttf':    'font/ttf'
		'.txt':    'text/plain'
		'.vsd':    'application/vnd.visio'
		'.wav':    'audio/wav'
		'.weba':   'audio/webm'
		'.webm':   'video/webm'
		'.webp':   'image/webp'
		'.woff':   'font/woff'
		'.woff2':  'font/woff2'
		'.xhtml':  'application/xhtml+xml'
		'.xls':    'application/vnd.ms-excel'
		'.xlsx':   'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
		'.xml':    'application/xml'
		'.xul':    'application/vnd.mozilla.xul+xml'
		'.zip':    'application/zip'
		'.3gp':    'video/3gpp'
		'.3g2':    'video/3gpp2'
		'.7z':     'application/x-7z-compressed'
	}
	default_host = 'localhost'
	default_port = 8080
)

fn main() {
	mut fp := flag.new_flag_parser(os.args)

	fp.application('vStatic')
	fp.version('v0.0.1')
	fp.limit_free_args(0, 0) or {}
	fp.skip_executable()

	port := fp.int('port', `p`, default_port, 'port')
	host := fp.string('host', `h`, default_host, 'hostname')
	mut root := fp.string('root', `r`, '.', 'root dir')
	mut base := fp.string('base', `b`, '', 'base url').trim('/')

	fp.finalize() or {
		eprintln(err)
		exit(1)
	}

	if !os.is_abs_path(root) {
		root = os.resource_abs_path(root)
	}

	if !os.exists(root) {
		eprintln('dir not exist $root')
		return
	}

	if base.len > 1 {
		base = '/$base'
	}

	addr_family := if host == 'localhost' || host.contains('.') {
		net.AddrFamily.ip
	} else {
		net.AddrFamily.ip6
	}

	mut l := net.listen_tcp(addr_family, '$host:$port') or {
		eprintln('failed to listen $err.code $err')
		return
	}

	println('Serving $root on http://$host:$port$base')

	for {
		mut conn := l.accept() or {
			eprintln('accept() failed with error: $err')
			continue
		}

		go handle_conn(mut conn, root, base)
	}
}

[manualfree]
fn handle_conn(mut conn net.TcpConn, root string, base string) {
	conn.set_read_timeout(30 * time.second)
	conn.set_write_timeout(30 * time.second)
	defer {
		conn.close() or {}
	}

	mut reader := io.new_buffered_reader(reader: conn)
	defer {
		reader.free()
	}

	req := http.parse_request(mut reader) or {
		// Prevents errors from being thrown when BufferedReader is empty
		if '$err' != 'none' {
			eprintln('error parsing request: $err')
		}
		return
	}

	url := urllib.parse(req.url) or {
		eprintln('error parsing path: $err')
		return
	}

	relative_path := get_request_path(url.path, base) or { '' }

	if relative_path.len > 0 {
		request_target := os.join_path_single(root, relative_path.trim_left('/'))

		if os.exists(request_target) {
			if os.is_dir(request_target) {
				render_dir(mut conn, request_target, url.path)
				return
			} else {
				send_file(mut conn, request_target)
			}
		}
	}

	conn.write(http_404.bytes()) or {}
}

fn get_request_path(url_path string, base string) ?string {
	if base.len == 0 {
		return url_path
	}

	if url_path.starts_with(base) {
		if url_path.len == base.len {
			return ''
		} else if url_path[base.len] == `/` {
			return url_path.substr(base.len, url_path.len)
		}
	}

	return none
}

struct Item {
	name        string [required]
	uri         string [required]
	size        string
	time        string
	is_dir      bool
	is_disabled bool
}

fn sort_item(a &Item, b &Item) int {
	if a.is_dir == b.is_dir {
		if a.name < b.name {
			return -1
		} else if a.name > b.name {
			return 1
		}

		return 0
	}

	return if a.is_dir { -1 } else { 1 }
}

fn render_dir(mut conn net.TcpConn, dir string, base_url string) {
	mut uri_prefix := ''
	if base_url != '/' {
		uri_prefix = escape_url_path(base_url)
	}

	mut files := read_dir(dir, uri_prefix)
	parent := os.dir(uri_prefix)

	files.sort_with_compare(sort_item)

	files.prepend(Item{
		name: '..'
		uri: parent
		is_dir: true
	})

	html := render_dir_html(base_url, files)
	send_response_to_client(mut conn, 'text/html; charset=UTF-8', html)
}

fn render_dir_html(base_url string, list []Item) string {
	window_title := base_url
	title := base_url

	return $tmpl('template/index.html')
}

fn read_dir(dir string, uri_prefix string) []Item {
	files := os.ls(dir) or { panic(err) }

	mut items := []Item{}

	for file in files {
		path := os.join_path(dir, file)

		is_dir := os.is_dir(path)
		uri := escape_url_path('/$file')
		size := if is_dir { '' } else { format_number(os.file_size(path)) }

		items << Item{
			name: file
			uri: '$uri_prefix$uri'
			size: size
			time: time.unix(os.file_last_mod_unix(path)).format_ss()
			is_dir: is_dir
		}
	}

	return items
}

[manualfree]
fn send_response_to_client(mut conn net.TcpConn, mimetype string, res string) bool {
	header := http.new_header_from_map({
		http.CommonHeader.content_type:   mimetype
		http.CommonHeader.content_length: res.len.str()
	})

	mut resp := http.Response{
		header: header.join(headers_close)
		text: res
	}
	resp.set_version(.v1_1)
	resp.set_status(http.status_from_int(200))
	send_string(mut conn, resp.bytestr()) or { return false }
	return true
}

fn send_file(mut conn net.TcpConn, path string) {
	ext := os.file_ext(path)
	data := os.read_file(path) or {
		eprint(err)
		send_string(mut conn, http_500.bytestr()) or {}
		return
	}
	content_type := mime_types[ext]
	if content_type == '' {
		// eprintln('no MIME type found for extension $ext')
		// send_string(mut conn, http_500.bytestr()) or { return }
		send_response_to_client(mut conn, mime_types['.bin'], data)
	} else {
		send_response_to_client(mut conn, content_type, data)
	}
}

fn send_string(mut conn net.TcpConn, s string) ? {
	conn.write(s.bytes()) ?
}

fn escape_url_path(path string) string {
	url := urllib.parse(path) or {
		eprintln('error parsing path: $err')
		return ''
	}

	return url.escaped_path()
}

fn format_number(n u64) string {
	mut arr := n.str().split('')

	for i := arr.len - 3; i > 0; i -= 3 {
		arr.insert(i, ',')
	}

	return arr.join('')
}
