<?php

use Ds\{Map, Set};

if (!$redis->exists('role_permissions')) {
	$role_permissions = new Map([
		'Anonymous' => new Map([
			'Home'     => new Set(['index', 'search']),
			'Sessions' => new Set(['new', 'create']),
			'Posts'    => new Set(['index', 'show']),
		]),
		'Admin' => new Map([
			'Home'           => new Set(['index', 'search']),
			'Sessions'       => new Set(['show', 'destroy', 'edit', 'update']),
			'Posts'          => new Set(['index', 'show', 'new', 'create', 'edit', 'update', 'destroy']),
			'Users'          => new Set(['index', 'show', 'new', 'create', 'edit', 'update', 'destroy']),
			'Monthly_Cashes' => new Set(['index', 'new', 'create']),
			'Expenses'       => new Set(['index', 'new', 'create', 'edit', 'update', 'destroy']),
			'Meetups'        => new Set(['index', 'new', 'create']),
		]),
		'Anggota' => new Map([
			'Home'           => new Set(['index', 'search']),
			'Sessions'       => new Set(['show', 'destroy', 'edit', 'update']),
			'Posts'          => new Set(['index', 'show']),
			'Users'          => new Set(['index', 'show']),
			'Monthly_Cashes' => new Set(['index']),
			'Expenses'       => new Set(['index']),
			'Meetups'        => new Set(['index']),
		]),
		'Bendahara' => new Map([
			'Home'           => new Set(['index', 'search']),
			'Sessions'       => new Set(['show', 'destroy', 'edit', 'update']),
			'Posts'          => new Set(['index', 'show']),
			'Users'          => new Set(['index', 'show']),
			'Monthly_Cashes' => new Set(['index', 'new', 'create']),
			'Expenses'       => new Set(['index', 'new', 'create', 'edit', 'update']),
			'Meetups'        => new Set(['index']),
		]),
		'Pengurus' => new Map([
			'Home'           => new Set(['index', 'search']),
			'Sessions'       => new Set(['show', 'destroy', 'edit', 'update']),
			'Posts'          => new Set(['index', 'show', 'new', 'create', 'edit', 'update']),
			'Users'          => new Set(['index', 'show', 'new', 'create', 'edit', 'update']),
			'Monthly_Cashes' => new Set(['index', 'new', 'create']),
			'Expenses'       => new Set(['index', 'new', 'create', 'edit', 'update']),
			'Meetups'        => new Set(['index', 'new', 'create']),
		]),
	]);
	$redis->set('role_permissions', igbinary_serialize($role_permissions));
}
