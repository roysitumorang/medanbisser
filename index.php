<?php

register_shutdown_function(function () {
	ob_get_level() && ob_end_flush();
	session_write_close();
});
// Output handlers must return a string (returning anything else is deprecated as of PHP 8.5).
ob_start(fn(string $buffer): string => preg_replace(['/(\s)+/s', '/\>(\s)+/s', '/(\s)+\</s', '/(\s+)?=(\s+)?/s'], ['\\1', '>', '<', '='], $buffer) ?? $buffer);
$db = new PDO('pgsql:dbname=medanbisser_erp', 'postgres', 'tR1adpass#', [
	PDO::ATTR_ERRMODE          => PDO::ERRMODE_EXCEPTION,
	PDO::ATTR_ORACLE_NULLS     => PDO::NULL_EMPTY_STRING,
	PDO::ATTR_PERSISTENT       => true,
	PDO::ATTR_EMULATE_PREPARES => false,
]);
require 'Utilities.php';
require 'Session.php';
new Session($db);
session_start();
const LOCALES = ['id_ID' => 'Bahasa Indonesia', 'en_US' => 'English'];
$locales = array_keys(LOCALES);
$locale  = &$_SESSION['locale'];
if (!in_array($locale, $locales, true)) {
	$locale = $locales[0];
}
$user_id = $_SESSION['user_id'] ?? null;
if ($user_id) {
	$stmt = $db->prepare('SELECT r.name FROM users u JOIN roles r ON u.role_id = r.id WHERE u.id = ?');
	$stmt->execute([$user_id]);
	define('ROLE', $stmt->fetchColumn() ?: 'Anonymous');
} else {
	define('ROLE', 'Anonymous');
}
$routes = require 'Routes.php';
$_SESSION['role_permissions'] = (require 'Role_Permissions.php')[ROLE] ?? [];
$route          = null;
$request_method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$request_uri    = explode('?', $_SERVER['REQUEST_URI'] ?? '/', 2)[0];
foreach ($routes as $item) {
	if ($request_method === $item['request_method'] && preg_match($item['url'], $request_uri, $param)) {
		$route = [
			'controller' => $item['controller'],
			'method'     => $item['method'],
			'param'      => $param,
		];
		break;
	}
}
$route ??= [
	'controller' => 'Posts',
	'method'     => 'show',
	'param'      => ['alias' => '404'],
];
$route_locale = $route['param']['locale'] ?? null;
if (in_array($route_locale, $locales, true) && $locale !== $route_locale) {
	$locale = $route_locale;
}
putenv("LANGUAGE={$locale}");
setlocale(LC_ALL, $locale . '.utf8');
bindtextdomain($locale, __DIR__ . '/locales');
bind_textdomain_codeset($locale, 'UTF-8');
textdomain($locale);
if (!in_array($route['method'], $_SESSION['role_permissions'][$route['controller']] ?? [], true)) {
	$route = [
		'controller' => 'Posts',
		'method'     => 'show',
		'param'      => ['alias' => '403'],
	];
}
$file       = "modules/{$route['controller']}.php";
$content    = '';
$javascript = '';
$login_menu = '';
$main_menu  = '';
if (file_exists($file)) {
	require 'Application.php';
	require $file;
	$class  = $route['controller'];
	$method = $route['method'];
	$module = new $class($db, $route);
	if ($module instanceof Application && method_exists($module, $method)) {
		$module->$method($_GET, $_POST, $_FILES);
		$content    = $module->get_content();
		$javascript = $module->get_javascript();
		$login_menu = $module->get_right_menu();
	}
}
require 'Menus.php';
foreach ($menus as $menu) {
	$main_menu .= '<li' . ($menu['active'] ? ' class="active"' : '') . '><a href="' . Utilities::link_to($menu['url']) . '"><i class="fa fa-' . $menu['icon'] . '">&nbsp;</i>&nbsp;' . $menu['title'] . '</a></li>';
}
unset($_SESSION['error_messages'], $_SESSION['alert']);
$template = file_get_contents('template.html');
echo sprintf($template, $main_menu, $login_menu, $content, $javascript ? sprintf('<script>%s</script>', $javascript) : '');
