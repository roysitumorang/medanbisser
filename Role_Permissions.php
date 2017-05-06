<?php

if (!apcu_exists('role_permissions')) {
	$role_permissions = [
		'Anonymous' => [
			'Home' => ['index', 'search'],
			'Sessions' => ['new', 'create'],
			'Posts' => ['index', 'show'],
		],
		'Admin' => [
			'Home' => ['index', 'search'],
			'Sessions' => ['show', 'destroy', 'edit', 'update'],
			'Posts' => ['index', 'show', 'new', 'create', 'edit', 'update', 'destroy'],
			'Users' => ['index', 'show', 'new', 'create', 'edit', 'update', 'destroy'],
			'Monthly_Cashes' => ['index', 'new', 'create'],
			'Expenses' => ['index', 'new', 'create', 'edit', 'update', 'destroy'],
			'Meetups' => ['index', 'new', 'create']
		],
		'Anggota' => [
			'Home' => ['index', 'search'],
			'Sessions' => ['show', 'destroy', 'edit', 'update'],
			'Posts' => ['index', 'show'],
			'Users' => ['index', 'show'],
			'Monthly_Cashes' => ['index'],
			'Expenses' => ['index'],
			'Meetups' => ['index']
		],
		'Bendahara' => [
			'Home' => ['index', 'search'],
			'Sessions' => ['show', 'destroy', 'edit', 'update'],
			'Posts' => ['index', 'show'],
			'Users' => ['index', 'show'],
			'Monthly_Cashes' => ['index', 'new', 'create'],
			'Expenses' => ['index', 'new', 'create', 'edit', 'update'],
			'Meetups' => ['index']
		],
		'Pengurus' => [
			'Home' => ['index', 'search'],
			'Sessions' => ['show', 'destroy', 'edit', 'update'],
			'Posts' => ['index', 'show', 'new', 'create', 'edit', 'update'],
			'Users' => ['index', 'show', 'new', 'create', 'edit', 'update'],
			'Monthly_Cashes' => ['index', 'new', 'create'],
			'Expenses' => ['index', 'new', 'create', 'edit', 'update'],
			'Meetups' => ['index', 'new', 'create']
		]
	];
	apcu_add('role_permissions', $role_permissions);
}
