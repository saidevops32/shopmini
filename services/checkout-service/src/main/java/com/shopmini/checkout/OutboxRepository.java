package com.shopmini.checkout;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface OutboxRepository extends JpaRepository<OutboxEvent, Long> {
    // SKIP LOCKED: with several replicas, each one takes different rows instead of blocking
    @Query(value = "select * from outbox where sent_at is null order by id limit 20 for update skip locked",
           nativeQuery = true)
    List<OutboxEvent> lockNextBatch();
}
