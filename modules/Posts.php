<?php

use Ds\Map;

class Posts extends Application {
	function __construct($db, $route) {
		parent::__construct($db, $route);
		!apcu_exists('posts_order_fields') && apcu_add('posts_order_fields', new Map(['Tanggal' => 'id DESC']));
		$this->_order_fields = apcu_fetch('posts_order_fields');
	}

	function index($get, $post, $files) {
		parent::index($get, $post, $files);
		$params = [];
		$this->_query .= ' ' . ($_SESSION['user_id'] ? "JOIN mv_users u ON r.id = u.role_id WHERE u.id = {$_SESSION['user_id']}" : "WHERE r.name = 'Anonymous'") . ' AND p.id NOT IN(4, 5)';
		if (!empty($get['q'])) {
			$q = sprintf('%%%s%%', $get['q']);
			$params = [$q, $q];
			$this->_query .= ' AND (p.title LIKE ? OR p.body LIKE ?)';
		}
		$this->_paginate($get, Utilities::link_to('posts'), $params, 'p.id, p.title, p.url_alias, c.full_name AS created_by, p.created_at, m.full_name AS modified_by, p.modified_at');
		$this->_content .= '
			<h2 class="navbar-form navbar-left"><i class="fa fa-list">&nbsp;</i> ' . ngettext('Post', 'Posts', 2) . '</h2>
			<form method="GET" action="' . Utilities::link_to('posts') . '" class="navbar-form navbar-right" role="search" onsubmit="(\'' . _('Search') . '\'==$(\'[name=q\').val())&amp;&amp;$(\'[name=q]\').val(\'\')">
				<input type="text" name="q" value="' . $get['q'] . '" class="form-control" placeholder="' . _('Search') . '">
				<button type="submit" class="btn btn-default"><i class="fa fa-search">&nbsp;</i> ' . _('Search') . '</button>' .
		($this->_allowed_to_access_link('Posts', 'new') ? '<a type="button" href="' . Utilities::link_to('posts/new') . '" class="btn btn-default"><i class="fa fa-user-plus">&nbsp;</i>&nbsp;' . _('New') . '</a>' : '') .
			'</form>
			<div class="clearfix"></div>' .
			$this->_pagination .
			'<table class="table table-striped table-hover table-condensed">
				<thead>
					<tr>
						<th class="text-center">' . _('Date') . '</th>
						<th class="text-center">' . _('Title') . '</th>
						<th class="text-center">' . _('Hits') . '</th>
						<th class="text-center">#</th>
					</tr>
				</thead>
				<tbody>';

		foreach ($this->_rows as $row) {
			$this->_content .= "
					<tr title='Dibuat oleh $row->created_by tanggal " . $this->_date_formatter->format(new DateTime($row->created_at)) . ($row->modified_by ? ", diupdate oleh $row->modified_by tanggal " . $this->_date_formatter->format(new DateTime($row->modified_at)) : '') . "'>
						<td class=\"text-center\">" . $this->_date_formatter->format(new DateTime($row->created_at)) . "</td>
						<td>$row->title</td>
						<td class=\"text-center\">" . $this->_db->query("SELECT SUM(hits) FROM post_access_logs WHERE post_id = $row->id")->fetchColumn() . "</td>
						<td class=\"text-center\">
							<a type=\"button\" href=\"" . Utilities::link_to($row->url_alias) . "\" class=\"btn btn-info\"><i class=\"fa fa-angle-double-right\">&nbsp;</i> " . _('Show') . "</a>
						</td>
					</tr>";
		}

		$this->_content .=<<<CONTENT
				</tbody>
			</table>
			$this->_pagination
CONTENT;
	}

	function show($get, $post, $files) {
		$post = $this->_prepare_data();
		if (!in_array($post->id, [4, 5])) {
			$stmt = $this->_db->prepare('INSERT INTO post_access_logs (post_id, user_id, hits, created_by, created_ip, created_at) VALUES (:post_id, :user_id, 1, :by, :ip, :at) ON CONFLICT (post_id, user_id) DO UPDATE SET hits = post_access_logs.hits + 1, modified_by = :by, modified_ip = :ip, modified_at = :at');
			$stmt->execute([
				':by'      => $_SESSION['user_id'],
				':ip'      => Utilities::get_real_ip_address(),
				':at'      => $this->_now->format('Y-m-d H:i:s'),
				':post_id' => $post->id,
				':user_id' => $_SESSION['user_id'],
			]);
		}
		$menu = '';
		if ($_SESSION['user_id']) {
			$menu = "<div class=\"form-group\">" .
					($this->_allowed_to_access_link('Posts', 'edit') ? "<a type=\"button\" href=\"" . Utilities::link_to("posts/$post->id/edit") . "\" class=\"btn btn-primary\"><i class=\"fa fa-edit\">&nbsp;</i>&nbsp;" . _('Edit') . "</a>" : '') .
					"<a type=\"button\" href=\"" . Utilities::link_to('posts') . "\" class=\"btn btn-default\"><i class=\"fa fa-step-backward\">&nbsp;</i> " . _('Back') . "</a>
				</div>";
		}
		$body = $post->body;
		if (preg_match_all('/{{(?P<url>[^}]+)}}/', $post->body, $matches)) {
			foreach ($matches[0] as $k => $match) {
				$body = str_replace($match, Utilities::link_to($matches['url'][$k]), $body);
			}
		}
		$this->_content .= "<h2>$post->title</h2>$menu $body $menu";
	}

	function new($get, $post, $files) {
		$this->_form($get, $post, Utilities::link_to('posts/create'));
	}

	function create($get, $post, $files) {
		$this->_validate($post, $files);
		if (empty($this->_error_messages)) {
			$post['slug'] = $this->_now->format('Y/m/d') . '/' . Utilities::slugify($post['title']);
			$id = parent::_db_insert('posts', $post);
			parent::_db_insert('post_permissions', ['post_id' => $id, 'role_id' => '1']);
			$this->_alert = ['type' => 'success', 'message' => _('Post successfully created')];
			Utilities::redirect_to($post['alias'] ?: $post['slug']);
		}
		$this->_alert = ['type' => 'danger', 'message' => _('Record invalid')];
		$this->_form($get, $post, Utilities::link_to('posts/create'));
	}

	function edit($get, $post, $files) {
		$content = $this->_prepare_data();
		foreach ($content as $k => $v) {
			!isset($post[$k]) && $post[$k] = $v;
		}
		$this->_form($get, $post, Utilities::link_to("posts/$content->id/update"));
	}

	function update($get, $post, $files) {
		$content = $this->_prepare_data();
		$this->_validate($post, $files);
		if ($this->_error_messages) {
			$this->_alert = ['type' => 'danger', 'message' => _('Record invalid')];
			$this->_form($get, $post, Utilities::link_to("posts/$content->id/update"));
			return;
		}
		parent::_db_update('posts', $post);
		$this->_alert = ['type' => 'success', 'message' => _('Post successfully updated')];
		Utilities::redirect_to($post['alias'] ?: $post['slug']);
	}

	private function _form($get, $post, $action) {
		$this->_content .=
		'<h2 class="navbar-form navbar-left">' . ngettext('Post', 'Posts', 1) . '</h2>
		<div class="clearfix"></div>' .
		$this->_get_form_notification() .
		'<form action="' . $action . '" method="POST" enctype="multipart/form-data" role="form">
			<input type="hidden" name="id" value="' . $this->_param['id'] . '">
			<div class="form-group">
				<div class="col-sm' . ($this->_error_messages['title'] ? ' has-error error' : '') . '">
					<label for="title" class="control-label">* ' . _('Title') . '</label>
				</div>
				<div class="col-sm' . ($this->_error_messages['title'] ? ' has-error error' : '') . '">
					<input type="text" class="form-control" id="title" name="title" placeholder="' . _('Title') . '" value="' . $post['title'] . '" size="140">
					<span class="help-block' . ($this->_error_messages['title'] ? ' text-danger' : '') . '">' . $this->_error_messages['title'] . '</span>
				</div>
			</div>
			<div class="form-group">
				<div class="col-sm' . ($this->_error_messages['alias'] ? ' has-error error' : '') . '">
					<label for="alias" class="control-label">' . _('URL Alias') . '</label>
				</div>
				<div class="col-sm' . ($this->_error_messages['alias'] ? ' has-error error' : '') . '">
					<input type="text" class="form-control" id="alias" name="alias" placeholder="' . _('URL Alias') . '" value="' . $post['alias'] . '" size="140">
					<span class="help-block' . ($this->_error_messages['alias'] ? ' text-danger' : '') . '">' . $this->_error_messages['alias'] . '</span>
				</div>
			</div>
			<div class="form-group">
				<div class="col-sm' . ($this->_error_messages['body'] ? ' has-error error' : '') . '">
					<label for="content" class="control-label">* ' . _('Body') . '</label>
				</div>
				<div class="col-sm' . ($this->_error_messages['body'] ? ' has-error error' : '') . '">
					<textarea id="content" name="body" class="form-control" placeholder="' . _('Body') . '">' . $post['body'] . '</textarea>
					<span class="help-block' . ($this->_error_messages['body'] ? ' text-danger' : '') . '">' . $this->_error_messages['body'] . '</span>
				</div>
			</div>
			<div class="form-group">
				<button type="submit" class="btn btn-primary"><i class="fa fa-save">&nbsp;</i> Simpan</button>
				<button type="reset" class="btn btn-danger"><i class="fa fa-undo">&nbsp;</i> Reset</button>
				<a type="button" href="' . Utilities::link_to('posts') . '" class="btn btn-default"><i class="fa fa-step-backward">&nbsp;</i> ' . _('Back') . '</a>
			</div>
		</form>';

		$this->_javascript .= 'CKEDITOR.replace("content")';
	}

	private function _validate($post, $files) {
		foreach (['title', 'body'] as $item) {
			empty($post[$item]) && $this->_error_messages[$item] = _('is blank');
		}
		$post['alias'] && $this->_db->query("SELECT COUNT(1) FROM posts WHERE alias = '{$post['alias']}'" . ($this->_param['id'] ? " AND id <> {$this->_param['id']}" : ''))->fetchColumn() && $this->_error_messages['alias'] = _('is taken');
		$this->_error_messages && $this->_alert = ['type' => 'danger', 'message' => _('Record invalid')];
	}

	private function _prepare_data() {
		$query = 'SELECT * FROM posts WHERE ';
		$param = [];
		if ($this->_param['alias']) {
			$query .= 'url_alias = ?';
			$param[] = $this->_param['alias'];
		} else if ($this->_param['slug']) {
			$query .= 'slug = ?';
			$param[] = $this->_param['slug'];
		} else if ($this->_param['id']) {
			$query .= 'id = ?';
			$param[] = $this->_param['id'];
		}
		$stmt = $this->_db->prepare($query);
		$stmt->execute($param);
		$post = $stmt->fetchObject();
		$post || Utilities::redirect_to(404);
		$this->_db->query("SELECT COUNT(1) FROM post_permissions p JOIN roles r ON p.role_id = r.id WHERE r.name = '" . ROLE . "' AND p.post_id = $post->id")->fetchColumn() || Utilities::redirect_to(403);
		return $post;
	}
}