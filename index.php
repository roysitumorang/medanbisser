<?php

register_shutdown_function(function($server) {
	ob_end_flush();
	session_write_close();
	$execution_time = (microtime(true) - $server['REQUEST_TIME_FLOAT']) * 1000;
	SeasLog::setBasePath(__DIR__);
	SeasLog::setLogger('log');
	SeasLog::info(sprintf("%s | %s | processed in %s ms | memory usage %s MB", $server['REQUEST_METHOD'], $server['REQUEST_URI'], $execution_time, memory_get_peak_usage(true) / 1048576));
}, $_SERVER);
ob_start(function($buffer) {
	return preg_replace(['/(\s)+/s', '/\>(\s)+/s', '/(\s)+\</s', '/(\s+)?=(\s+)?/s'], ['\\1', '>', '<', '='], $buffer);
});
$db = new PDO('pgsql:dbname=medanbisser_erp', 'postgres', 'tR1adpass#', [
	PDO::ATTR_ERRMODE          => PDO::ERRMODE_EXCEPTION,
	PDO::ATTR_ORACLE_NULLS     => PDO::NULL_EMPTY_STRING,
	PDO::ATTR_PERSISTENT       => 1,
	PDO::ATTR_EMULATE_PREPARES => 0,
]);
$redis = new Redis;
$redis->pconnect('127.0.0.1');
require 'Session.php';
new Session($db);
session_start();
define('LOCALES', ['id_ID' => 'Bahasa Indonesia', 'en_US' => 'English']);
$locales = array_keys(LOCALES);
$locale  = &$_SESSION['locale'];
if (!in_array($locale, $locales)) {
	$locale = $locales[0];
}
define('ROLE', $_SESSION['user_id'] ? $db->query("SELECT r.name FROM users u JOIN roles r ON u.role_id = r.id WHERE u.id = {$_SESSION['user_id']}")->fetchColumn() : 'Anonymous');
require 'Utilities.php';
require 'Routes.php';
$routes = unserialize($redis->get('routes'));
require 'Role_Permissions.php';
$_SESSION['role_permissions'] = unserialize($redis->get('role_permissions'))->get(ROLE);
$route = null;
foreach (['request_method', 'request_time', 'request_time_float', 'redirect_url'] as $route) {
	$k     = strtoupper($route);
	$$route = $_SERVER[$k];
}
foreach ($routes as $route) {
	if ($request_method === $route->get('request_method') && preg_match($route->get('url'), $redirect_url, $param)) {
		$route = [
			'controller' => $route->get('controller'),
			'method'     => $route->get('method'),
			'param'      => $param
		];
		break;
	}
}
if (!$route) {
	$route = [
		'controller' => 'Posts',
		'method'     => 'show',
		'param'      => ['alias' => 404],
	];
}
if (in_array($route['param']['locale'], $locales) && $locale <> $route['param']['locale']) {
	$locale = $route['param']['locale'];
}
putenv("LANGUAGE={$locale}");
setlocale(LC_ALL, $locale . '.utf8');
bindtextdomain($locale, dirname(__FILE__) . '/locales');
bind_textdomain_codeset($domain, 'UTF-8');
textdomain($locale);
if (!$_SESSION['role_permissions']->get($route['controller'])->contains($route['method'])) {
	$route = [
		'controller' => 'Posts',
		'method'     => 'show',
		'param'      => ['alias' => 403],
	];
}
$file       = "modules/{$route['controller']}.php";
$content    = '';
$javascript = '';
$login_menu = '';
$main_menu  = '';
if (file_exists($file)) {
	include 'Application.php';
	include $file;
	$module  = $route['controller'];
	$$module = new $module($db, $route);
	$method  = $route['method'];

	if (is_subclass_of($$module, 'Application') && method_exists($$module, $method)) {
		call_user_func_array([$$module, $method], [$_GET, $_POST, $_FILES]);
		$content    = $$module->get_content();
		$javascript = $$module->get_javascript();
		$login_menu = $$module->get_right_menu();
	}
}
require 'Menus.php';
foreach ($menus as $route) {
	$main_menu .= '<li' . ($route['active'] ? ' class="active"' : '') . '><a href="' . Utilities::link_to($route['url']) . '"><i class="fa fa-' . $route['icon'] . '">&nbsp;</i>&nbsp;' . $route['title'] . '</a></li>';
}
foreach (['error_messages', 'alert'] as $k) {
	if (isset($_SESSION[$k])) {
		unset($_SESSION[$k]);
	}
}
if (!$redis->exists('template')) {
	$redis->set('template', file_get_contents('template.html'));
}
echo sprintf($redis->get('template'), $main_menu, $login_menu, $content, $javascript ? sprintf('<script>%s</script>', $javascript) : '');