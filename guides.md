---
layout: default
title: City guides
permalink: /guides
---

# City guides

<ul class="post-list">
{% for post in site.posts %}
  {% if post.tag == "guide" %}
  <li>
    <a href="{{ post.url | relative_url }}">
      <span class="post-list__title">{{ post.title }}</span>
      <span class="post-list__date">{{ post.date | date: "%Y-%m-%d" }}</span>
    </a>
  </li>
  {% endif %}
{% endfor %}
</ul>
