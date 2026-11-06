package com.shopmini.checkout;

import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.QueueBuilder;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * The queue is declared on BOTH sides with identical settings, so messages published before
 * the worker has ever started are kept instead of being dropped by an unbound exchange.
 */
@Configuration
public class Messaging {
    public static final String EXCHANGE = "shop.events";
    public static final String ORDER_CREATED = "order.created";
    public static final String QUEUE = "notification.order-created";

    @Bean
    TopicExchange shopEvents() { return new TopicExchange(EXCHANGE, true, false); }

    @Bean
    Queue orderCreatedQueue() { return QueueBuilder.durable(QUEUE).build(); }

    @Bean
    Binding orderCreatedBinding(Queue orderCreatedQueue, TopicExchange shopEvents) {
        return BindingBuilder.bind(orderCreatedQueue).to(shopEvents).with(ORDER_CREATED);
    }
}
