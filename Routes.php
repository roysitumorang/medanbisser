<?php

$routes = [
	[
		'url'            => 'home',
		'request_method' => 'GET',
		'controller'     => 'Home',
		'method'         => 'index',
	], [
		'url'            => 'search',
		'request_method' => 'GET',
		'controller'     => 'Home',
		'method'         => 'search',
	], [
		'url'            => 'sessions\/new',
		'request_method' => 'GET',
		'controller'     => 'Sessions',
		'method'         => 'new',
	], [
		'url'            => 'sessions\/create',
		'request_method' => 'POST',
		'controller'     => 'Sessions',
		'method'         => 'create',
	], [
		'url'            => 'sessions\/destroy',
		'request_method' => 'GET',
		'controller'     => 'Sessions',
		'method'         => 'destroy',
	], [
		'url'            => 'sessions\/mine',
		'request_method' => 'GET',
		'controller'     => 'Sessions',
		'method'         => 'show',
	], [
		'url'            => 'sessions\/mine\/edit',
		'request_method' => 'GET',
		'controller'     => 'Sessions',
		'method'         => 'edit',
	], [
		'url'            => 'sessions\/mine\/update',
		'request_method' => 'POST',
		'controller'     => 'Sessions',
		'method'         => 'update',
	], [
		'url'            => '(?P<slug>\d{4}\/\d{2}\/\d{2}\/[a-z0-9-]+)',
		'request_method' => 'GET',
		'controller'     => 'Posts',
		'method'         => 'show',
	], [
		'url'            => 'posts',
		'request_method' => 'GET',
		'controller'     => 'Posts',
		'method'         => 'index',
	], [
		'url'            => 'posts\/(?P<id>\d+)',
		'request_method' => 'POST',
		'controller'     => 'Posts',
		'method'         => 'show',
	], [
		'url'            => 'posts\/new',
		'request_method' => 'GET',
		'controller'     => 'Posts',
		'method'         => 'new',
	], [
		'url'            => 'posts\/create',
		'request_method' => 'POST',
		'controller'     => 'Posts',
		'method'         => 'create',
	], [
		'url'            => 'posts\/(?P<id>\d+)\/edit',
		'request_method' => 'GET',
		'controller'     => 'Posts',
		'method'         => 'edit',
	], [
		'url'            => 'posts\/(?P<id>\d+)\/update',
		'request_method' => 'POST',
		'controller'     => 'Posts',
		'method'         => 'update',
	], [
		'url'            => 'posts\/(?P<id>\d+)\/destroy',
		'request_method' => 'POST',
		'controller'     => 'Posts',
		'method'         => 'destroy',
	], [
		'url'            => 'users',
		'request_method' => 'GET',
		'controller'     => 'Users',
		'method'         => 'index',
	], [
		'url'            => 'users\/new',
		'request_method' => 'GET',
		'controller'     => 'Users',
		'method'         => 'new',
	], [
		'url'            => 'users\/create',
		'request_method' => 'POST',
		'controller'     => 'Users',
		'method'         => 'create',
	], [
		'url'            => 'users\/(?P<id>\d+)',
		'request_method' => 'GET',
		'controller'     => 'Users',
		'method'         => 'show',
	], [
		'url'            => 'users\/(?P<id>\d+)\/edit',
		'request_method' => 'GET',
		'controller'     => 'Users',
		'method'         => 'edit',
	], [
		'url'            => 'users\/(?P<id>\d+)\/update',
		'request_method' => 'POST',
		'controller'     => 'Users',
		'method'         => 'update',
	], [
		'url'            => 'users\/(?P<id>\d+)\/destroy',
		'request_method' => 'POST',
		'controller'     => 'Users',
		'method'         => 'destroy',
	], [
		'url'            => 'monthly-cashes',
		'request_method' => 'GET',
		'controller'     => 'Monthly_Cashes',
		'method'         => 'index',
	], [
		'url'            => 'monthly-cashes\/new',
		'request_method' => 'GET',
		'controller'     => 'Monthly_Cashes',
		'method'         => 'new',
	], [
		'url'            => 'monthly-cashes\/create',
		'request_method' => 'POST',
		'controller'     => 'Monthly_Cashes',
		'method'         => 'create',
	], [
		'url'            => 'meetups',
		'request_method' => 'GET',
		'controller'     => 'Meetups',
		'method'         => 'index',
	], [
		'url'            => 'meetups\/new',
		'request_method' => 'GET',
		'controller'     => 'Meetups',
		'method'         => 'new',
	], [
		'url'            => 'meetups\/create',
		'request_method' => 'POST',
		'controller'     => 'Meetups',
		'method'         => 'create',
	], [
		'url'            => 'expenses',
		'request_method' => 'GET',
		'controller'     => 'Expenses',
		'method'         => 'index',
	], [
		'url'            => 'expenses\/new',
		'request_method' => 'GET',
		'controller'     => 'Expenses',
		'method'         => 'new',
	], [
		'url'            => 'expenses\/create',
		'request_method' => 'POST',
		'controller'     => 'Expenses',
		'method'         => 'create',
	], [
		'url'            => 'expenses\/(?P<id>\d+)',
		'request_method' => 'GET',
		'controller'     => 'Expenses',
		'method'         => 'show',
	], [
		'url'            => 'expenses\/(?P<id>\d+)\/edit',
		'request_method' => 'GET',
		'controller'     => 'Expenses',
		'method'         => 'edit',
	], [
		'url'            => 'expenses\/(?P<id>\d+)\/update',
		'request_method' => 'POST',
		'controller'     => 'Expenses',
		'method'         => 'update',
	], [
		'url'            => 'expenses\/(?P<id>\d+)\/destroy',
		'request_method' => 'POST',
		'controller'     => 'Expenses',
		'method'         => 'destroy',
	], [
		'url'            => '(?P<alias>[a-z0-9-]+)',
		'request_method' => 'GET',
		'controller'     => 'Posts',
		'method'         => 'show',
	],
];
foreach ($routes as $i => $route) {
	$route['url'] = '/^\/(?P<locale>en_US|id_ID)\/' . $route['url'] . '(\/)?$/';
	$routes[$i] = $route;
}
return $routes;