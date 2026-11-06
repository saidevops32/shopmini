package com.shopmini.checkout;

import java.nio.charset.StandardCharsets;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageDeliveryMode;
import org.springframework.amqp.core.MessageProperties;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class OutboxPublisher {
    private static final Logger log = LoggerFactory.getLogger(OutboxPublisher.class);
    private final OutboxRepository outbox;
    private final RabbitTemplate rabbit;

    public OutboxPublisher(OutboxRepository outbox, RabbitTemplate rabbit) {
        this.outbox = outbox;
        this.rabbit = rabbit;
    }

    @Scheduled(fixedDelay = 2000)
    @Transactional
    public void publishPending() {
        for (OutboxEvent event : outbox.lockNextBatch()) {
            try {
                rabbit.invoke(ops -> {
                    MessageProperties props = new MessageProperties();
                    props.setContentType("application/json");
                    props.setDeliveryMode(MessageDeliveryMode.PERSISTENT);
                    ops.send(Messaging.EXCHANGE, Messaging.ORDER_CREATED,
                            new Message(event.getPayload().getBytes(StandardCharsets.UTF_8), props));
                    ops.waitForConfirmsOrDie(5000);   // the broker must confirm before we mark it sent
                    return true;
                });
                event.markSent();
            } catch (Exception e) {
                // broker down or no confirm: leave the row unsent and retry on the next tick
                log.warn("outbox publish failed, will retry: {}", e.getClass().getSimpleName());
                return;
            }
        }
    }
}
