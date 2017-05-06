<?php

$all_menus = [
	['title' => _('Home'), 'active' => $route['controller'] == 'Home', 'url' => 'home', 'icon' => 'home'],
	['title' => ngettext('User', 'Users', 2), 'active' => $route['controller'] == 'Users', 'url' => 'users', 'icon' => 'group'],
	['title' => ngettext('Monthly Cash', 'Monthly Cashes', 2), 'active' => $route['controller'] == 'Monthly_Cashes', 'url' => 'monthly-cashes', 'icon' => 'dollar'],
	['title' => ngettext('Expense', 'Expenses', 2), 'active' => $route['controller'] == 'Expenses', 'url' => 'expenses', 'icon' => 'shopping-basket'],
	['title' => ngettext('Meetup', 'Meetups', 2), 'active' => $route['controller'] == 'Meetups', 'url' => 'meetups', 'icon' => 'calendar'],
	['title' => ngettext('Post', 'Posts', 2), 'active' => $route['controller'] == 'Posts' && $_SERVER['REQUEST_URI'] != Utilities::link_to('about-us'), 'url' => 'posts', 'icon' => 'list']
];

$menus = in_array(ROLE, ['Anonymous', 'Admin', 'Anggota', 'Bendahara', 'Pengurus']) ? ($menus = ROLE == 'Anonymous' ? [$all_menus[0]] : $all_menus) : [];
