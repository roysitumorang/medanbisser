<?php

register_shutdown_function(function($server) {
	ob_end_flush();
	session_write_close();
	$execution_time = (microtime(true) - $server['REQUEST_TIME_FLOAT']) * 1000;
	SeasLog::setBasePath(__DIR__);
	SeasLog::setLogger('log');
	SeasLog::info(sprintf("%s | %s | processed in %s ms | memory usage %s MB", $server['REQUEST_METHOD'], $server['REQUEST_URI'], $execution_time, memory_get_peak_usage(true) / 1048576));
}, $_SERVER);
ob_start(function($buffer) { return preg_replace(['/(\s)+/s', '/\>(\s)+/s', '/(\s)+\</s', '/(\s+)?=(\s+)?/s'], ['\\1', '>', '<', '='], $buffer); });
$db = new PDO('pgsql:dbname=medanbisser_erp', 'postgres', 'postgres', [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_ORACLE_NULLS => PDO::NULL_EMPTY_STRING, PDO::ATTR_PERSISTENT => true, PDO::ATTR_EMULATE_PREPARES => false]);
$redis = new Redis;
$redis->pconnect('127.0.0.1');
require 'Session.php';
new Session($db);
session_start();
define('LOCALES', ['id_ID' => 'Bahasa Indonesia', 'en_US' => 'English']);
$locales = array_keys(LOCALES);
$locale = &$_SESSION['locale'];
!in_array($locale, $locales) && $locale = $locales[0];
define('ROLE', $_SESSION['user_id'] ? $db->query("SELECT r.name FROM users u JOIN roles r ON u.role_id = r.id WHERE u.id = {$_SESSION['user_id']}")->fetchColumn() : 'Anonymous');
require 'Utilities.php';
require 'Routes.php';
define('ROUTES', igbinary_unserialize($redis->get('routes')));
require 'Role_Permissions.php';
define('ROLE_PERMISSIONS', igbinary_unserialize($redis->get('role_permissions'))[ROLE]);
$route = null;
foreach (['request_method', 'request_time', 'request_time_float', 'redirect_url'] as $item) {
	$k = strtoupper($item);
	$$item = $_SERVER[$k];
}
foreach (ROUTES as $item) {
	if ($request_method === $item->get('request_method') && preg_match($item->get('url'), $redirect_url, $param)) {
		$route = [
			'controller' => $item->get('controller'),
			'method'     => $item->get('method'),
			'param'      => $param
		];
		break;
	}
}
$route || Utilities::redirect_to(404);
in_array($route['param']['locale'], $locales) && $locale <> $route['param']['locale'] && $locale = $route['param']['locale'];
putenv("LANGUAGE=$locale");
setlocale(LC_ALL, $locale . '.utf8');
bindtextdomain($locale, dirname(__FILE__) . '/locales');
bind_textdomain_codeset($domain, 'UTF-8');
textdomain($locale);
in_array($route['method'], ROLE_PERMISSIONS[$route['controller']]) || Utilities::redirect_to(403);
$file = "modules/{$route['controller']}.php";
$content = '';
$javascript = '';
$login_menu = '';
$main_menu = '';
if (file_exists($file)) {
	include 'Application.php';
	include $file;
	$module = $route['controller'];
	$$module = new $module($db, $route);
	$method = $route['method'];

	if (is_subclass_of($$module, 'Application') && method_exists($$module, $method)) {
		call_user_func_array([$$module, $method], [$_GET, $_POST, $_FILES]);
		$content = $$module->get_content();
		$javascript = $$module->get_javascript();
		$login_menu = $$module->get_right_menu();
	}
}
require 'Menus.php';
foreach ($menus as $item) {
	$main_menu .= '<li' . ($item['active'] ? ' class="active"' : '') . '><a href="' . Utilities::link_to($item['url']) . '"><i class="fa fa-' . $item['icon'] . '">&nbsp;</i>&nbsp;' . $item['title'] . '</a></li>';
}
foreach (['error_messages', 'alert'] as $k) { if (isset($_SESSION[$k])) unset($_SESSION[$k]); }
!$redis->exists('template') && $redis->set('template', file_get_contents('template.html'));
echo sprintf($redis->get('template'), $main_menu, $login_menu, $content, $javascript ? sprintf('<script>%s</script>', $javascript) : '');
