# history : torch.tensor

# 假设kvcache是按照 位置t索引的
# page_size : 每个page的kv token个数
# kvcache_page_tables : 所有page的索引
# kvcache_pages: 所有page的kv cache， [batch_size, num_pages , page_size, hidden_size]
# 以下代码假忽略batch维度

# kv_cache[t] = kvcache_pages[kvcache_page_tables[t // page_size] ][t % page_size]

# 第一步：decode history 得到 kvcache_pages, kvcache_page_tables 和 top2 的children tokens
# children_tokens: [beam_widthx1], 被摊平为1维tensor

# method B的伪代码
children_tokens, kvcache_pages, kvcache_page_tables = decode(history)
kv_size = len(history)
children_embedding = embedding(children_tokens)

# decode step 1 : linear projection
children_query, children_key, children_value = qvk_linear(children_tokens)

# 每个method有自己的update_kvcache函数
kvcache_pages, kvcache_page_tables = update_kvcache(kvcache_pages, kvcache_page_tables, children_key, children_value, current_index, kv_size)
kv_size += beam_width 

childre_embedding = paged_beam_attention(children_query, kvcache_pages, kvcache_page_tables, kv_size)

children_logits = lm_head(children_embedding)

ancestors = topk(children_logits)